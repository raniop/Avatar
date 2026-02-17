import { Message, Child, Avatar, ParentQuestion, ParentGuidance } from '@prisma/client';
import { SpeechToText } from './SpeechToText';
import { TextToSpeech } from './TextToSpeech';
import { ConversationEngine } from '../conversation-engine/ConversationEngine';

/**
 * VoicePipeline orchestrates the full voice conversation flow:
 *
 * Audio In -> Whisper STT -> Conversation Engine (Claude) -> TTS -> Audio Out
 *
 * This is the main entry point for voice-based conversation messages.
 */

export interface VoiceMessageParams {
  audioBuffer: Buffer;
  conversationId: string;
  systemPrompt: string;
  messageHistory: Message[];
  child: Child & { avatar?: Avatar | null };
  avatar: Avatar | null;
  parentQuestions: ParentQuestion[];
  parentGuidance?: ParentGuidance[];
  runtimeGuidance?: string[];
  locale: string;
}

export interface VoiceMessageResult {
  // Child's side
  childTranscript: string;
  childAudioDuration: number;

  // Avatar's side
  avatarText: string;
  avatarAudioUrl: string;
  avatarAudioDuration: number;
  avatarAudioBuffer: Buffer;
  avatarEmotion: string;
  metadata?: Record<string, unknown>;
}

export class VoicePipeline {
  private stt: SpeechToText;
  private tts: TextToSpeech;
  private conversationEngine: ConversationEngine;

  constructor() {
    this.stt = new SpeechToText();
    this.tts = new TextToSpeech();
    this.conversationEngine = new ConversationEngine();
  }

  /**
   * Transcribe audio to text (STT only).
   * Used when the caller wants to split the pipeline into phases.
   */
  async transcribe(audioBuffer: Buffer, locale: string) {
    return this.stt.transcribe(audioBuffer, locale);
  }

  /**
   * Process a voice message through the full pipeline:
   * 1. Transcribe child's audio to text (STT)
   * 2. Process text through conversation engine (Claude)
   * 3. Convert avatar response to audio (TTS)
   */
  async processVoiceMessage(
    params: VoiceMessageParams,
  ): Promise<VoiceMessageResult> {
    const {
      audioBuffer,
      conversationId,
      systemPrompt,
      messageHistory,
      child,
      avatar,
      parentQuestions,
      parentGuidance,
      runtimeGuidance,
      locale,
    } = params;

    // ── Step 1: Speech-to-Text ─────────────────────
    const transcription = await this.stt.transcribe(audioBuffer, locale);

    if (!transcription.text.trim()) {
      // If no speech detected, return a gentle prompt
      const fallbackText =
        locale === 'he'
          ? 'לא שמעתי טוב. אתה יכול לומר את זה שוב?'
          : "I didn't quite hear that. Can you say it again?";

      const fallbackAudio = await this.tts.synthesizeForChild(
        fallbackText,
        avatar?.voiceId || undefined,
        child.age,
        locale,
      );

      return {
        childTranscript: '',
        childAudioDuration: transcription.duration,
        avatarText: fallbackText,
        avatarAudioUrl: fallbackAudio.audioUrl,
        avatarAudioDuration: fallbackAudio.audioDuration,
        avatarAudioBuffer: fallbackAudio.audioBuffer,
        avatarEmotion: 'curious',
      };
    }

    // ── Step 2: Conversation Engine ────────────────
    const avatarResponse = await this.conversationEngine.processChildMessage({
      conversationId,
      childText: transcription.text,
      systemPrompt,
      messageHistory,
      child,
      avatar,
      parentQuestions,
      parentGuidance,
      runtimeGuidance,
      locale,
    });

    // ── Step 3: Text-to-Speech ─────────────────────
    const speechResult = await this.tts.synthesizeForChild(
      avatarResponse.text,
      avatar?.voiceId || undefined,
      child.age,
      locale,
    );

    return {
      childTranscript: transcription.text,
      childAudioDuration: transcription.duration,
      avatarText: avatarResponse.text,
      avatarAudioUrl: speechResult.audioUrl,
      avatarAudioDuration: speechResult.audioDuration,
      avatarAudioBuffer: speechResult.audioBuffer,
      avatarEmotion: avatarResponse.emotion,
      metadata: avatarResponse.metadata,
    };
  }

  /**
   * Generate audio for an avatar text response (used for text-only
   * conversations that need audio output).
   */
  async generateAvatarAudio(
    text: string,
    voiceId?: string,
    childAge?: number,
    locale: string = 'en',
  ): Promise<{
    audioUrl: string;
    audioBuffer: Buffer;
    audioDuration: number;
  }> {
    const result = await this.tts.synthesizeForChild(text, voiceId, childAge, locale);
    return {
      audioUrl: result.audioUrl,
      audioBuffer: result.audioBuffer,
      audioDuration: result.audioDuration,
    };
  }
}
