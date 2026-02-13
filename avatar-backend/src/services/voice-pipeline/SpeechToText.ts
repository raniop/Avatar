import OpenAI from 'openai';
import { Readable } from 'stream';

const openai = new OpenAI();

export interface TranscriptionResult {
  text: string;
  language: string;
  duration: number;
}

/**
 * SpeechToText service using OpenAI Whisper API.
 *
 * Converts child audio recordings to text for processing
 * by the conversation engine.
 */
export class SpeechToText {
  /**
   * Transcribe audio buffer to text using Whisper.
   *
   * @param audioBuffer - Raw audio data (supports wav, mp3, m4a, webm, mp4, mpeg, mpga, oga, ogg)
   * @param locale - Expected language ('en' or 'he') to improve accuracy
   * @returns Transcription result with text, detected language, and duration
   */
  async transcribe(
    audioBuffer: Buffer,
    locale: string = 'en',
  ): Promise<TranscriptionResult> {
    try {
      // Convert Buffer to a File-like object for the OpenAI API
      const audioFile = new File([audioBuffer], 'audio.wav', {
        type: 'audio/wav',
      });

      const response = await openai.audio.transcriptions.create({
        model: 'whisper-1',
        file: audioFile,
        language: this.mapLocaleToWhisperLanguage(locale),
        response_format: 'verbose_json',
      });

      // The verbose_json format includes duration and language
      const verboseResponse = response as unknown as {
        text: string;
        language: string;
        duration: number;
      };

      return {
        text: verboseResponse.text || '',
        language: verboseResponse.language || locale,
        duration: verboseResponse.duration || 0,
      };
    } catch (error) {
      console.error('Speech-to-text transcription failed:', error);
      throw new Error(
        `Failed to transcribe audio: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
    }
  }

  /**
   * Transcribe audio from a readable stream.
   */
  async transcribeStream(
    stream: Readable,
    locale: string = 'en',
  ): Promise<TranscriptionResult> {
    const chunks: Buffer[] = [];

    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }

    const audioBuffer = Buffer.concat(chunks);
    return this.transcribe(audioBuffer, locale);
  }

  /**
   * Map app locale codes to Whisper language codes.
   */
  private mapLocaleToWhisperLanguage(locale: string): string {
    const languageMap: Record<string, string> = {
      en: 'en',
      he: 'he',
    };

    return languageMap[locale] || 'en';
  }
}
