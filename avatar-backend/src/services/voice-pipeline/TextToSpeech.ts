import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';
import { promises as fs } from 'fs';
import path from 'path';
import { getEnv } from '../../config/environment';

const openai = new OpenAI();

export type TTSVoice = 'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer';

export interface SpeechResult {
  audioBuffer: Buffer;
  audioUrl: string;
  audioDuration: number;
  format: string;
}

/**
 * TextToSpeech service using OpenAI TTS API.
 *
 * Converts avatar text responses into speech audio
 * for playback in the mobile app.
 */
export class TextToSpeech {
  private uploadDir: string;

  constructor() {
    this.uploadDir = getEnv().UPLOAD_DIR;
  }

  /**
   * Convert text to speech audio.
   *
   * @param text - The text to convert to speech
   * @param voiceId - The voice to use (maps to OpenAI TTS voices)
   * @param speed - Speech speed (0.25 to 4.0, default 1.0)
   * @returns Speech result with audio buffer, URL, and metadata
   */
  async synthesize(
    text: string,
    voiceId?: string,
    speed: number = 1.0,
  ): Promise<SpeechResult> {
    try {
      const voice = this.mapVoiceId(voiceId);

      const response = await openai.audio.speech.create({
        model: 'tts-1-hd',
        voice,
        input: text,
        speed: Math.max(0.25, Math.min(4.0, speed)),
        response_format: 'mp3',
      });

      // Get audio buffer from response
      const arrayBuffer = await response.arrayBuffer();
      const audioBuffer = Buffer.from(arrayBuffer);

      // Estimate duration based on text length and speed
      // Average speaking rate: ~150 words per minute
      const wordCount = text.split(/\s+/).length;
      const estimatedDuration = (wordCount / 150) * 60 / speed;

      // Save to file storage
      const audioUrl = await this.saveAudioFile(audioBuffer);

      return {
        audioBuffer,
        audioUrl,
        audioDuration: Math.round(estimatedDuration * 10) / 10,
        format: 'mp3',
      };
    } catch (error) {
      console.error('Text-to-speech synthesis failed:', error);
      throw new Error(
        `Failed to synthesize speech: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
    }
  }

  /**
   * Synthesize speech optimized for children's content.
   * Uses slightly slower speed and child-friendly voice.
   */
  async synthesizeForChild(
    text: string,
    voiceId?: string,
    childAge?: number,
  ): Promise<SpeechResult> {
    // Adjust speed based on child's age (younger = slower)
    let speed = 1.0;
    if (childAge !== undefined) {
      if (childAge <= 4) speed = 0.85;
      else if (childAge <= 6) speed = 0.9;
      else if (childAge <= 8) speed = 0.95;
      // 9+ uses default speed
    }

    return this.synthesize(text, voiceId, speed);
  }

  /**
   * Save audio buffer to file storage and return URL path.
   */
  private async saveAudioFile(audioBuffer: Buffer): Promise<string> {
    const filename = `avatar-${uuidv4()}.mp3`;
    const audioDir = path.join(this.uploadDir, 'audio');

    // Ensure directory exists
    await fs.mkdir(audioDir, { recursive: true });

    const filePath = path.join(audioDir, filename);
    await fs.writeFile(filePath, audioBuffer);

    // Return relative URL path
    return `/uploads/audio/${filename}`;
  }

  /**
   * Map avatar voice ID to OpenAI TTS voice.
   *
   * The avatar's voiceId in the database can be a custom identifier
   * that we map to the closest OpenAI voice.
   */
  private mapVoiceId(voiceId?: string): TTSVoice {
    if (!voiceId) return 'nova'; // Default: warm, friendly female voice

    const voiceMap: Record<string, TTSVoice> = {
      // Direct OpenAI voice names
      alloy: 'alloy',
      echo: 'echo',
      fable: 'fable',
      onyx: 'onyx',
      nova: 'nova',
      shimmer: 'shimmer',

      // Custom avatar voice identifiers
      friendly_female: 'nova',
      friendly_male: 'echo',
      playful_female: 'shimmer',
      playful_male: 'fable',
      warm_female: 'nova',
      warm_male: 'alloy',
      energetic_female: 'shimmer',
      energetic_male: 'echo',
    };

    return voiceMap[voiceId] || 'nova';
  }
}
