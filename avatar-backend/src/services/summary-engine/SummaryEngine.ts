import Anthropic from '@anthropic-ai/sdk';
import { Child, Message, ParentQuestion } from '@prisma/client';
import prisma from '../../config/prisma';

const anthropic = new Anthropic();

export interface SummaryParams {
  conversationId: string;
  messages: Message[];
  child: Child;
  parentQuestions: ParentQuestion[];
  locale: string;
}

export interface ConversationSummaryData {
  briefSummary: string;
  detailedSummary: string;
  moodAssessment: string;
  keyTopics: string[];
  emotionalFlags: Record<string, unknown>;
  questionAnswers: Record<string, unknown>;
  engagementLevel: string;
  talkativenessScore: number;
}

/**
 * SummaryEngine generates post-conversation analysis using Claude.
 *
 * After a conversation ends, it analyzes the full transcript to produce:
 * - Brief and detailed summaries for the parent dashboard
 * - Mood assessment of the child during the conversation
 * - Key topics discussed
 * - Emotional flags (if any concerning patterns were detected)
 * - Answers to parent questions that were explored
 * - Engagement and talkativeness metrics
 */
export class SummaryEngine {
  /**
   * Generate a complete conversation summary and save to database.
   */
  async generateSummary(params: SummaryParams): Promise<ConversationSummaryData> {
    const { conversationId, messages, child, parentQuestions, locale } = params;

    if (messages.length < 2) {
      // Not enough messages for a meaningful summary
      const defaultSummary = this.getDefaultSummary();
      await this.saveSummary(conversationId, defaultSummary);
      return defaultSummary;
    }

    const transcript = this.buildTranscript(messages);
    const summaryData = await this.analyzeConversation(
      transcript,
      child,
      parentQuestions,
      locale,
    );

    await this.saveSummary(conversationId, summaryData);

    return summaryData;
  }

  /**
   * Build a readable transcript from messages.
   */
  private buildTranscript(messages: Message[]): string {
    return messages
      .map((msg) => {
        const speaker =
          msg.role === 'CHILD'
            ? 'Child'
            : msg.role === 'AVATAR'
              ? 'Avatar'
              : msg.role === 'PARENT_INTERVENTION'
                ? 'Parent (intervention)'
                : 'System';

        const emotionTag = msg.emotion ? ` [${msg.emotion}]` : '';

        return `${speaker}${emotionTag}: ${msg.textContent}`;
      })
      .join('\n');
  }

  /**
   * Analyze the conversation transcript using Claude.
   */
  private async analyzeConversation(
    transcript: string,
    child: Child,
    parentQuestions: ParentQuestion[],
    locale: string,
  ): Promise<ConversationSummaryData> {
    const parentQuestionsText = parentQuestions.length
      ? parentQuestions
          .map((q) => `- ${q.questionText} (topic: ${q.topic || 'general'})`)
          .join('\n')
      : 'None specified';

    const analysisPrompt = `You are an expert child psychologist analyzing a conversation between a child and their AI companion avatar.

## Child Profile
- Name: ${child.name}
- Age: ${child.age} years old
- Interests: ${child.interests?.join(', ') || 'not specified'}
- Development Goals: ${child.developmentGoals?.join(', ') || 'not specified'}

## Parent Questions to Track
${parentQuestionsText}

## Conversation Transcript
${transcript}

## Analysis Instructions
Analyze this conversation and produce a JSON response with the following structure:

{
  "briefSummary": "A 1-2 sentence summary suitable for a parent dashboard notification",
  "detailedSummary": "A 3-5 sentence detailed summary covering key topics, child's engagement, and notable moments",
  "moodAssessment": "One of: very_positive, positive, neutral, mixed, negative, concerning",
  "keyTopics": ["topic1", "topic2", ...],
  "emotionalFlags": {
    "distressDetected": false,
    "joyExpressed": true,
    "angerExpressed": false,
    "anxietySignals": false,
    "sadnessExpressed": false,
    "socialConcerns": false,
    "notes": "Any additional observations"
  },
  "questionAnswers": {
    "questionsExplored": [
      {
        "questionText": "The parent question that was explored",
        "wasAddressed": true,
        "childResponse": "Brief summary of what the child shared"
      }
    ]
  },
  "engagementLevel": "One of: highly_engaged, engaged, moderately_engaged, low_engagement, disengaged",
  "talkativenessScore": 7.5
}

The talkativenessScore should be 0-10, where:
- 0-2: Very quiet, minimal responses
- 3-4: Brief responses, not very talkative
- 5-6: Average engagement
- 7-8: Talkative and engaged
- 9-10: Very talkative and enthusiastic

Respond with ONLY the JSON object, no additional text.`;

    try {
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1500,
        messages: [
          {
            role: 'user',
            content: analysisPrompt,
          },
        ],
      });

      const content = response.content[0];
      if (content.type !== 'text') {
        return this.getDefaultSummary();
      }

      return this.parseSummaryResponse(content.text);
    } catch (error) {
      console.error('Failed to generate conversation summary:', error);
      return this.getDefaultSummary();
    }
  }

  /**
   * Parse Claude's summary response.
   */
  private parseSummaryResponse(rawText: string): ConversationSummaryData {
    try {
      // Extract JSON from response
      const jsonMatch = rawText.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return this.getDefaultSummary();
      }

      const parsed = JSON.parse(jsonMatch[0]);

      return {
        briefSummary: parsed.briefSummary || 'Conversation completed.',
        detailedSummary:
          parsed.detailedSummary || 'No detailed analysis available.',
        moodAssessment: parsed.moodAssessment || 'neutral',
        keyTopics: Array.isArray(parsed.keyTopics)
          ? parsed.keyTopics
          : [],
        emotionalFlags:
          typeof parsed.emotionalFlags === 'object'
            ? parsed.emotionalFlags
            : {},
        questionAnswers:
          typeof parsed.questionAnswers === 'object'
            ? parsed.questionAnswers
            : {},
        engagementLevel: parsed.engagementLevel || 'moderately_engaged',
        talkativenessScore:
          typeof parsed.talkativenessScore === 'number'
            ? Math.max(0, Math.min(10, parsed.talkativenessScore))
            : 5,
      };
    } catch {
      console.error('Failed to parse summary response');
      return this.getDefaultSummary();
    }
  }

  /**
   * Save summary to database.
   */
  private async saveSummary(
    conversationId: string,
    data: ConversationSummaryData,
  ): Promise<void> {
    await prisma.conversationSummary.upsert({
      where: { conversationId },
      create: {
        conversationId,
        briefSummary: data.briefSummary,
        detailedSummary: data.detailedSummary,
        moodAssessment: data.moodAssessment,
        keyTopics: data.keyTopics,
        emotionalFlags: data.emotionalFlags,
        questionAnswers: data.questionAnswers,
        engagementLevel: data.engagementLevel,
        talkativenessScore: data.talkativenessScore,
      },
      update: {
        briefSummary: data.briefSummary,
        detailedSummary: data.detailedSummary,
        moodAssessment: data.moodAssessment,
        keyTopics: data.keyTopics,
        emotionalFlags: data.emotionalFlags,
        questionAnswers: data.questionAnswers,
        engagementLevel: data.engagementLevel,
        talkativenessScore: data.talkativenessScore,
      },
    });
  }

  /**
   * Default summary for edge cases (too short conversations, API failures).
   */
  private getDefaultSummary(): ConversationSummaryData {
    return {
      briefSummary: 'Conversation was too brief for detailed analysis.',
      detailedSummary:
        'The conversation did not contain enough exchanges for a meaningful analysis. This may indicate the session was interrupted or the child was not engaged.',
      moodAssessment: 'neutral',
      keyTopics: [],
      emotionalFlags: {},
      questionAnswers: {},
      engagementLevel: 'low_engagement',
      talkativenessScore: 2,
    };
  }
}
