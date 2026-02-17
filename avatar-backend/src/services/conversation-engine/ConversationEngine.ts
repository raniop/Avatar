import Anthropic from '@anthropic-ai/sdk';
import { Child, Avatar, MissionTemplate, ParentQuestion, ParentGuidance, Message } from '@prisma/client';
import { PromptBuilder, PromptContext } from './PromptBuilder';
import { SafetyFilter } from './SafetyFilter';
import { QuestionWeaver } from './QuestionWeaver';

const anthropic = new Anthropic();

// ──────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────

export interface AdventureChoice {
  id: string;
  emoji: string;
  label: string;
}

export interface MiniGameConfig {
  type: 'catch' | 'match' | 'sort' | 'sequence';
  round: number;
}

export interface AdventureState {
  sceneIndex: number;
  sceneName: string;
  sceneEmojis: string[];
  interactionType: 'choice' | 'voice' | 'celebrate' | 'miniGame';
  choices: AdventureChoice[] | null;
  miniGame: MiniGameConfig | null;
  starsEarned: number;
  isSceneComplete: boolean;
  isAdventureComplete: boolean;
  collectible: { emoji: string; name: string } | null;
}

export interface AvatarResponse {
  text: string;
  emotion: string;
  metadata?: Record<string, unknown>;
  adventure?: AdventureState;
}

export interface BuildSystemPromptParams {
  child: Child;
  avatar: Avatar | null;
  mission: MissionTemplate | null;
  parentQuestions: ParentQuestion[];
  parentGuidance: ParentGuidance[];
  locale: string;
}

export interface GenerateOpeningParams {
  conversationId: string;
  child: Child;
  avatar: Avatar | null;
  mission: MissionTemplate | null;
  locale: string;
  systemPrompt: string;
}

export interface ProcessMessageParams {
  conversationId: string;
  childText: string;
  systemPrompt: string;
  messageHistory: Message[];
  child: Child;
  avatar: Avatar | null;
  parentQuestions: ParentQuestion[];
  parentGuidance?: ParentGuidance[];
  runtimeGuidance?: string[];
  locale: string;
  hasMission?: boolean;
}

// ──────────────────────────────────────────────
// Engine
// ──────────────────────────────────────────────

/**
 * ConversationEngine is the core AI conversation service.
 *
 * It orchestrates:
 * - System prompt construction via PromptBuilder
 * - Child message safety checking via SafetyFilter
 * - Parent question integration via QuestionWeaver
 * - LLM response generation via Anthropic Claude
 * - Avatar response safety verification
 */
export class ConversationEngine {
  private promptBuilder: PromptBuilder;
  private safetyFilter: SafetyFilter;
  private questionWeaver: QuestionWeaver;

  constructor() {
    this.promptBuilder = new PromptBuilder();
    this.safetyFilter = new SafetyFilter();
    this.questionWeaver = new QuestionWeaver();
  }

  /**
   * Build the full system prompt for a conversation.
   */
  buildSystemPrompt(params: BuildSystemPromptParams): string {
    const context: PromptContext = {
      child: params.child,
      avatar: params.avatar,
      mission: params.mission,
      parentQuestions: params.parentQuestions,
      parentGuidance: params.parentGuidance || [],
      locale: params.locale,
    };

    return this.promptBuilder.buildSystemPrompt(context);
  }

  /**
   * Generate the avatar's opening message for a new conversation.
   */
  async generateOpeningMessage(
    params: GenerateOpeningParams,
  ): Promise<AvatarResponse> {
    const { child, avatar, mission, locale, systemPrompt } = params;

    const avatarName = avatar?.name || 'Buddy';

    let openingInstruction: string;

    if (mission) {
      const missionTitle =
        locale === 'he' ? mission.titleHe : mission.titleEn;
      openingInstruction =
        `Generate the OPENING message for a new adventure called "${missionTitle}" (theme: ${mission.theme}). ` +
        `Greet ${child.name} by name, set the scene dramatically, and get them excited for the game! ` +
        `Keep text to 2-3 short exciting sentences. ` +
        `You MUST respond with the full adventure JSON format as described in your system prompt, ` +
        `with interactionType: "miniGame" and miniGame: { "type": "<game_type>", "round": 1 }. ` +
        `The game type for theme "${mission.theme}" is determined by the theme mapping in your system prompt.`;
    } else {
      openingInstruction =
        `Generate a warm, friendly greeting from ${avatarName} to ${child.name}. ` +
        `This is a free-form conversation. Greet the child by name and ask them ` +
        `something fun and open-ended about their day. Keep it to 2-3 short sentences. ` +
        `Respond with JSON: {"text": "...", "emotion": "happy"}`;
    }

    try {
      const response = await anthropic.messages.create({
        model: mission ? 'claude-sonnet-4-20250514' : 'claude-haiku-4-5-20251001',
        max_tokens: mission ? 800 : 300,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: openingInstruction,
          },
        ],
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        return this.defaultOpeningMessage(child.name, avatarName, locale === 'he');
      }

      return this.parseAvatarResponse(content.text, mission ? 'excited' : 'happy');
    } catch (error) {
      console.error('Failed to generate opening message:', error);
      return this.defaultOpeningMessage(child.name, avatarName, locale === 'he');
    }
  }

  /**
   * Process a child's message and generate an avatar response.
   *
   * Pipeline:
   * 1. Safety check on child's message
   * 2. Determine if a parent question should be woven in
   * 3. Build conversation context for Claude
   * 4. Generate response via Anthropic API
   * 5. Safety check on avatar's response
   * 6. Return final response with emotion and metadata
   */
  async processChildMessage(
    params: ProcessMessageParams,
  ): Promise<AvatarResponse> {
    const {
      childText,
      systemPrompt,
      messageHistory,
      child,
      avatar,
      parentQuestions,
      runtimeGuidance,
      locale,
      hasMission,
    } = params;

    const isHebrew = locale === 'he';

    // ── Step 1: Safety check child's message ─────
    const childSafety = this.safetyFilter.checkChildMessage(childText);

    // Build metadata from safety flags
    let metadata: Record<string, unknown> = {};

    if (childSafety.flags.length > 0) {
      const safetyMeta = this.safetyFilter.generateSafetyMetadata(
        childSafety.flags,
      );
      if (safetyMeta) {
        metadata = { ...metadata, ...safetyMeta };
      }
    }

    // ── Step 2: Evaluate question weaving ────────
    const childMessages = messageHistory.filter((m) => m.role === 'CHILD');
    const turnCount = childMessages.length + 1; // +1 for current message

    const weaving = this.questionWeaver.evaluate({
      messages: messageHistory,
      parentQuestions,
      conversationTurnCount: turnCount,
    });

    // ── Step 3: Build messages array for Claude ──
    // Combine question weaving hint with runtime guidance into a single guidance string
    const guidanceHints: string[] = [];
    if (weaving.shouldWeaveQuestion && weaving.integrationHint) {
      guidanceHints.push(weaving.integrationHint);
    }
    if (runtimeGuidance?.length) {
      guidanceHints.push(`Parent just sent live guidance: ${runtimeGuidance.join('; ')}`);
    }

    const claudeMessages = this.buildClaudeMessages(
      messageHistory,
      childText,
      guidanceHints.length > 0 ? guidanceHints.join('\n') : null,
      childSafety.severity !== 'none'
        ? this.buildSafetyContextNote(childSafety.severity)
        : null,
      isHebrew,
      hasMission,
    );

    // ── Step 4: Generate response via Claude ─────
    try {
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: hasMission ? 800 : 500,
        system: systemPrompt,
        messages: claudeMessages,
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        return this.defaultResponse();
      }

      const avatarResponse = this.parseAvatarResponse(content.text, 'neutral');

      // ── Step 5: Safety check avatar's response ──
      const avatarSafety = this.safetyFilter.checkAvatarResponse(
        avatarResponse.text,
      );

      if (!avatarSafety.isSafe && avatarSafety.filteredContent) {
        return {
          text: avatarSafety.filteredContent,
          emotion: 'neutral',
          metadata: {
            ...metadata,
            avatarResponseFiltered: true,
          },
        };
      }

      // ── Step 6: Add weaving metadata ────────────
      if (weaving.shouldWeaveQuestion && weaving.question) {
        metadata.questionWeaved = {
          questionId: weaving.question.id,
          questionText: weaving.question.questionText,
          topic: weaving.question.topic,
        };
      }

      return {
        text: avatarResponse.text,
        emotion: avatarResponse.emotion,
        metadata: Object.keys(metadata).length > 0 ? metadata : undefined,
        adventure: avatarResponse.adventure,
      };
    } catch (error) {
      console.error('Failed to process child message:', error);
      return this.defaultResponse(isHebrew);
    }
  }

  /**
   * Build the messages array for Claude API from conversation history.
   */
  private buildClaudeMessages(
    messageHistory: Message[],
    currentChildText: string,
    questionWeaveHint: string | null,
    safetyNote: string | null,
    isHebrew: boolean = false,
    hasMission: boolean = false,
  ): Anthropic.MessageParam[] {
    const messages: Anthropic.MessageParam[] = [];

    // Convert message history to Claude format
    // Skip messages with empty content to avoid Anthropic API errors
    for (const msg of messageHistory) {
      if (msg.role === 'CHILD') {
        if (msg.textContent?.trim()) {
          messages.push({
            role: 'user',
            content: msg.textContent,
          });
        }
      } else if (msg.role === 'AVATAR') {
        if (msg.textContent?.trim()) {
          messages.push({
            role: 'assistant',
            content: msg.textContent,
          });
        }
      } else if (msg.role === 'PARENT_INTERVENTION') {
        // Parent interventions are injected as system-like context
        messages.push({
          role: 'user',
          content: `[PARENT GUIDANCE: ${msg.textContent}]`,
        });
        messages.push({
          role: 'assistant',
          content: '[Acknowledged parent guidance. Adjusting conversation accordingly.]',
        });
      }
      // SYSTEM messages are part of the system prompt, not message history
    }

    // Strip leading assistant messages (opening avatar greeting is in system prompt context)
    while (messages.length > 0 && messages[0].role === 'assistant') {
      messages.shift();
    }

    // Ensure strict user/assistant alternation (required by Anthropic API).
    // Merge consecutive same-role messages with newline separator.
    const merged: Anthropic.MessageParam[] = [];
    for (const msg of messages) {
      const last = merged[merged.length - 1];
      if (last && last.role === msg.role) {
        // Merge into previous message
        last.content = `${last.content}\n${msg.content}`;
      } else {
        merged.push({ ...msg });
      }
    }
    messages.length = 0;
    messages.push(...merged);

    // Build the current user message with optional context
    let currentMessage = currentChildText;
    const langReminder = isHebrew
      ? ' You MUST respond in Hebrew (עברית).'
      : '';

    const jsonFormat = hasMission
      ? 'Output JSON with adventure state: {"text": "your response", "emotion": "emotion_name", "adventure": {"sceneIndex": N, "sceneName": "...", "sceneEmojis": ["..."], "interactionType": "miniGame|voice|celebrate", "choices": null, "miniGame": {"type": "catch|match|sort|sequence", "round": N} or null, "starsEarned": N, "isSceneComplete": false, "isAdventureComplete": false, "collectible": null}}'
      : 'Output JSON: {"text": "your response", "emotion": "emotion_name"}';

    if (questionWeaveHint || safetyNote) {
      const contextParts: string[] = [];

      if (safetyNote) {
        contextParts.push(`[INTERNAL NOTE - ${safetyNote}]`);
      }

      if (questionWeaveHint) {
        contextParts.push(`[INTERNAL GUIDANCE - ${questionWeaveHint}]`);
      }

      // Prepend context as internal notes (the model sees these but the child doesn't)
      currentMessage =
        contextParts.join('\n') +
        '\n\n' +
        `Child says: "${currentChildText}"\n\n` +
        `Respond naturally as the avatar.${langReminder} ${jsonFormat}`;
    } else {
      currentMessage =
        `Child says: "${currentChildText}"\n\n` +
        `Respond naturally as the avatar.${langReminder} ${jsonFormat}`;
    }

    messages.push({
      role: 'user',
      content: currentMessage,
    });

    return messages;
  }

  /**
   * Parse the avatar response from Claude's output.
   * Handles both JSON and plain text responses.
   */
  private parseAvatarResponse(
    rawText: string,
    defaultEmotion: string,
  ): AvatarResponse {
    // Try to parse as JSON
    try {
      // Strip markdown code blocks if present
      const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();

      // Try parsing the entire cleaned text as JSON first (handles nested adventure objects)
      let parsed: any = null;
      try {
        parsed = JSON.parse(cleaned);
      } catch {
        // If that fails, try to extract a top-level JSON object using brace matching
        const startIdx = cleaned.indexOf('{');
        if (startIdx !== -1) {
          let depth = 0;
          let endIdx = -1;
          for (let i = startIdx; i < cleaned.length; i++) {
            if (cleaned[i] === '{') depth++;
            else if (cleaned[i] === '}') {
              depth--;
              if (depth === 0) { endIdx = i; break; }
            }
          }
          if (endIdx !== -1) {
            parsed = JSON.parse(cleaned.substring(startIdx, endIdx + 1));
          }
        }
      }

      if (parsed && parsed.text) {
        const response: AvatarResponse = {
          text: parsed.text,
          emotion: parsed.emotion || defaultEmotion,
        };

        // Extract adventure state if present
        if (parsed.adventure && typeof parsed.adventure === 'object') {
          response.adventure = {
            sceneIndex: parsed.adventure.sceneIndex ?? 0,
            sceneName: parsed.adventure.sceneName ?? '',
            sceneEmojis: Array.isArray(parsed.adventure.sceneEmojis)
              ? parsed.adventure.sceneEmojis
              : [],
            interactionType: ['choice', 'voice', 'celebrate', 'miniGame'].includes(parsed.adventure.interactionType)
              ? parsed.adventure.interactionType
              : 'voice',
            choices: Array.isArray(parsed.adventure.choices)
              ? parsed.adventure.choices.map((c: any) => ({
                  id: c.id || '',
                  emoji: c.emoji || '',
                  label: c.label || '',
                }))
              : null,
            miniGame: parsed.adventure.miniGame && typeof parsed.adventure.miniGame === 'object'
              ? {
                  type: ['catch', 'match', 'sort', 'sequence'].includes(parsed.adventure.miniGame.type)
                    ? parsed.adventure.miniGame.type
                    : 'catch',
                  round: parsed.adventure.miniGame.round ?? 1,
                }
              : null,
            starsEarned: parsed.adventure.starsEarned ?? 0,
            isSceneComplete: parsed.adventure.isSceneComplete ?? false,
            isAdventureComplete: parsed.adventure.isAdventureComplete ?? false,
            collectible: parsed.adventure.collectible
              ? { emoji: parsed.adventure.collectible.emoji || '', name: parsed.adventure.collectible.name || '' }
              : null,
          };
        }

        return response;
      }
    } catch {
      // JSON parsing failed, use raw text
    }

    // Fall back to using the raw text as-is
    const cleanText = rawText
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();

    return {
      text: cleanText || "That's really interesting! Tell me more!",
      emotion: defaultEmotion,
    };
  }

  /**
   * Build a safety context note for the model.
   */
  private buildSafetyContextNote(
    severity: 'none' | 'low' | 'medium' | 'high' | 'critical',
  ): string {
    switch (severity) {
      case 'critical':
        return (
          'SAFETY ALERT: The child may be expressing distress or disclosing harm. ' +
          'Respond with warmth and empathy. Do NOT dismiss their feelings. ' +
          'Gently validate their emotions. Do not probe for details.'
        );
      case 'high':
        return (
          'CONTENT NOTE: The child mentioned content that may be age-inappropriate. ' +
          'Gently redirect to a more suitable topic without making the child feel bad.'
        );
      case 'medium':
        return (
          'CONTEXT NOTE: The child may be discussing sensitive topics. ' +
          'Handle with empathy and age-appropriate care.'
        );
      case 'low':
        return (
          'MINOR NOTE: The child used some language that could be improved. ' +
          'Model better communication without being preachy.'
        );
      default:
        return '';
    }
  }

  /**
   * Default opening message fallback.
   */
  private defaultOpeningMessage(
    childName: string,
    avatarName: string,
    isHebrew: boolean = false,
  ): AvatarResponse {
    return {
      text: isHebrew
        ? `היי ${childName}! זה אני, ${avatarName}! כל כך שמח לראות אותך היום. מה משהו כיף שקרה לך?`
        : `Hey ${childName}! It's me, ${avatarName}! I'm so happy to see you today. What's something fun that happened to you?`,
      emotion: 'happy',
    };
  }

  /**
   * Default response fallback.
   */
  private defaultResponse(isHebrew: boolean = false): AvatarResponse {
    return {
      text: isHebrew
        ? 'וואו, זה ממש מגניב! אני אוהב לשמוע על זה. מה עוד יש לך בראש?'
        : "Wow, that's really cool! I love hearing about that. What else is on your mind?",
      emotion: 'curious',
    };
  }
}
