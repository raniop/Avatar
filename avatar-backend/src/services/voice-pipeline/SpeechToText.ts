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
      // Log audio details for debugging
      console.log(`[STT] Received audio buffer: ${audioBuffer.length} bytes, locale=${locale}`);

      // Validate WAV header if present
      if (audioBuffer.length >= 44) {
        const riff = audioBuffer.subarray(0, 4).toString('ascii');
        const wave = audioBuffer.subarray(8, 12).toString('ascii');
        const fmt = audioBuffer.subarray(12, 16).toString('ascii');
        const sampleRate = audioBuffer.readUInt32LE(24);
        const bitsPerSample = audioBuffer.readUInt16LE(34);
        const channels = audioBuffer.readUInt16LE(22);
        const dataSize = audioBuffer.readUInt32LE(40);
        console.log(`[STT] WAV header: RIFF=${riff}, WAVE=${wave}, fmt=${fmt}, sampleRate=${sampleRate}, bits=${bitsPerSample}, channels=${channels}, dataSize=${dataSize}`);

        if (riff !== 'RIFF' || wave !== 'WAVE') {
          console.error(`[STT] Invalid WAV header! Expected RIFF/WAVE, got ${riff}/${wave}`);
        }

        // Estimate audio duration from data size
        const bytesPerSecond = sampleRate * channels * (bitsPerSample / 8);
        const estimatedDuration = dataSize / bytesPerSecond;
        console.log(`[STT] Estimated audio duration: ${estimatedDuration.toFixed(2)}s`);

        // Reject audio that is too short (< 0.3 seconds)
        if (estimatedDuration < 0.3) {
          console.warn(`[STT] Audio too short (${estimatedDuration.toFixed(2)}s), returning empty transcription`);
          return { text: '', language: locale, duration: estimatedDuration };
        }
      } else {
        console.warn(`[STT] Audio buffer too small for WAV header: ${audioBuffer.length} bytes`);
      }

      // Convert Buffer to a File-like object for the OpenAI API
      const audioFile = new File([audioBuffer], 'audio.wav', {
        type: 'audio/wav',
      });

      console.log(`[STT] Sending to Whisper API...`);

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

      console.log(`[STT] Whisper result: text="${(verboseResponse.text || '').substring(0, 80)}", lang=${verboseResponse.language}, duration=${verboseResponse.duration}s`);

      return {
        text: verboseResponse.text || '',
        language: verboseResponse.language || locale,
        duration: verboseResponse.duration || 0,
      };
    } catch (error) {
      console.error('[STT] Speech-to-text transcription failed:', error);
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
