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
 * TextToSpeech service supporting multiple providers:
 * - Cartesia Sonic 3 for Hebrew (natural-sounding, low latency)
 * - OpenAI TTS-HD for English (fallback)
 */
export class TextToSpeech {
  private uploadDir: string;
  private cartesiaApiKey: string | undefined;

  constructor() {
    this.uploadDir = getEnv().UPLOAD_DIR;
    this.cartesiaApiKey = process.env.CARTESIA_API_KEY;
  }

  /**
   * Convert text to speech audio.
   */
  async synthesize(
    text: string,
    voiceId?: string,
    speed: number = 1.0,
    locale: string = 'en',
  ): Promise<SpeechResult> {
    // Use Cartesia for Hebrew if API key is available
    if (locale === 'he' && this.cartesiaApiKey) {
      return this.synthesizeWithCartesia(text, voiceId, speed, locale);
    }

    return this.synthesizeWithOpenAI(text, voiceId, speed);
  }

  /**
   * Synthesize speech optimized for children's content.
   */
  async synthesizeForChild(
    text: string,
    voiceId?: string,
    childAge?: number,
    locale: string = 'en',
  ): Promise<SpeechResult> {
    let speed = 1.0;
    if (childAge !== undefined) {
      if (childAge <= 4) speed = 0.85;
      else if (childAge <= 6) speed = 0.9;
      else if (childAge <= 8) speed = 0.95;
    }

    return this.synthesize(text, voiceId, speed, locale);
  }

  /**
   * Synthesize using Cartesia Sonic 3 (excellent Hebrew support).
   */
  /**
   * Map avatar voice ID to a Cartesia voice ID based on gender.
   * All Cartesia voices are multilingual — they speak Hebrew natively.
   */
  private mapCartesiaVoiceId(voiceId?: string): string {
    // Male: Emilio - Friendly Optimist (upbeat, warm — perfect for a boy's avatar friend)
    const CARTESIA_MALE = 'b0689631-eee7-4a6c-bb86-195f1d267c2e';
    // Female: Brooke - Big Sister (approachable, warm — great for a girl's avatar friend)
    const CARTESIA_FEMALE = 'e07c00bc-4134-4eae-9ea4-1a55fb45746b';

    if (!voiceId) return CARTESIA_MALE;

    // Check if the voiceId indicates a female voice
    if (voiceId.includes('female') || voiceId === 'nova' || voiceId === 'shimmer') {
      return CARTESIA_FEMALE;
    }

    return CARTESIA_MALE;
  }

  private async synthesizeWithCartesia(
    text: string,
    voiceId: string | undefined,
    speed: number,
    locale: string,
  ): Promise<SpeechResult> {
    try {
      const cartesiaVoice = this.mapCartesiaVoiceId(voiceId);
      console.log(`[TTS] Using Cartesia Sonic 3 for locale=${locale}, voice=${cartesiaVoice}, avatarVoice=${voiceId}, text="${text.substring(0, 60)}..."`);

      const response = await fetch('https://api.cartesia.ai/tts/bytes', {
        method: 'POST',
        headers: {
          'X-API-Key': this.cartesiaApiKey!,
          'Cartesia-Version': '2025-04-16',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model_id: 'sonic-3',
          transcript: text,
          voice: {
            mode: 'id',
            id: cartesiaVoice,
          },
          language: locale,
          output_format: {
            container: 'mp3',
            sample_rate: 44100,
            bit_rate: 128,
          },
          ...(speed !== 1.0 && {
            generation_config: {
              speed: Math.max(0.6, Math.min(1.5, speed)),
            },
          }),
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[TTS] Cartesia API error: ${response.status} ${errorText}`);
        throw new Error(`Cartesia API error: ${response.status}`);
      }

      const arrayBuffer = await response.arrayBuffer();
      const audioBuffer = Buffer.from(arrayBuffer);

      const wordCount = text.split(/\s+/).length;
      const estimatedDuration = (wordCount / 150) * 60 / speed;

      const audioUrl = await this.saveAudioFile(audioBuffer);

      console.log(`[TTS] Cartesia OK: size=${audioBuffer.length}, url=${audioUrl}`);

      return {
        audioBuffer,
        audioUrl,
        audioDuration: Math.round(estimatedDuration * 10) / 10,
        format: 'mp3',
      };
    } catch (error) {
      console.error('[TTS] Cartesia failed, falling back to OpenAI:', error);
      return this.synthesizeWithOpenAI(text, undefined, speed);
    }
  }

  /**
   * Synthesize using OpenAI TTS-HD (fallback / English).
   */
  private async synthesizeWithOpenAI(
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

      const arrayBuffer = await response.arrayBuffer();
      const audioBuffer = Buffer.from(arrayBuffer);

      const wordCount = text.split(/\s+/).length;
      const estimatedDuration = (wordCount / 150) * 60 / speed;

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
   * Save audio buffer to file storage and return URL path.
   */
  private async saveAudioFile(audioBuffer: Buffer): Promise<string> {
    const filename = `avatar-${uuidv4()}.mp3`;
    const audioDir = path.join(this.uploadDir, 'audio');

    await fs.mkdir(audioDir, { recursive: true });

    const filePath = path.join(audioDir, filename);
    await fs.writeFile(filePath, audioBuffer);

    return `/uploads/audio/${filename}`;
  }

  /**
   * Map avatar voice ID to OpenAI TTS voice.
   */
  private mapVoiceId(voiceId?: string): TTSVoice {
    if (!voiceId) return 'nova';

    const voiceMap: Record<string, TTSVoice> = {
      alloy: 'alloy',
      echo: 'echo',
      fable: 'fable',
      onyx: 'onyx',
      nova: 'nova',
      shimmer: 'shimmer',

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
