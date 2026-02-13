import { ParentQuestion, Message } from '@prisma/client';

/**
 * QuestionWeaver determines when and how to integrate parent questions
 * into the conversation flow naturally.
 *
 * It uses heuristics based on:
 * - Conversation length (don't ask too early)
 * - Topic relevance (look for natural openings)
 * - Question priority (higher priority = more eager to weave in)
 * - Previous attempts (don't repeat questions already explored)
 */

export interface QuestionWeavingResult {
  shouldWeaveQuestion: boolean;
  question: ParentQuestion | null;
  integrationHint: string | null;
}

export interface WeavingContext {
  messages: Message[];
  parentQuestions: ParentQuestion[];
  conversationTurnCount: number;
}

// Minimum number of message exchanges before weaving in a question
const MIN_TURNS_BEFORE_QUESTION = 4;

// Maximum questions to weave per conversation
const MAX_QUESTIONS_PER_SESSION = 2;

// Topic keyword mapping for detecting natural openings
const TOPIC_KEYWORDS: Record<string, string[]> = {
  feelings: [
    'feel',
    'happy',
    'sad',
    'angry',
    'scared',
    'excited',
    'worried',
    'mood',
    'emotion',
  ],
  school: [
    'school',
    'teacher',
    'class',
    'homework',
    'learn',
    'study',
    'test',
    'grade',
    'friend',
  ],
  friends: [
    'friend',
    'play',
    'together',
    'share',
    'fight',
    'argue',
    'best friend',
    'group',
  ],
  family: [
    'mom',
    'dad',
    'mommy',
    'daddy',
    'brother',
    'sister',
    'family',
    'home',
    'parent',
  ],
  health: [
    'eat',
    'food',
    'sleep',
    'tired',
    'sick',
    'hurt',
    'doctor',
    'exercise',
    'sport',
  ],
  behavior: [
    'trouble',
    'sorry',
    'mean',
    'nice',
    'kind',
    'share',
    'help',
    'rule',
    'fair',
  ],
  interests: [
    'like',
    'love',
    'favorite',
    'fun',
    'game',
    'play',
    'watch',
    'read',
    'draw',
    'build',
  ],
  fears: [
    'afraid',
    'scared',
    'dark',
    'monster',
    'nightmare',
    'worry',
    'nervous',
    'alone',
  ],
};

export class QuestionWeaver {
  private questionsAskedThisSession: Set<string> = new Set();

  /**
   * Evaluate whether to weave a parent question into the next response.
   */
  evaluate(context: WeavingContext): QuestionWeavingResult {
    const { messages, parentQuestions, conversationTurnCount } = context;

    // Don't weave if too early in conversation
    if (conversationTurnCount < MIN_TURNS_BEFORE_QUESTION) {
      return { shouldWeaveQuestion: false, question: null, integrationHint: null };
    }

    // Don't weave if we've already asked enough
    if (this.questionsAskedThisSession.size >= MAX_QUESTIONS_PER_SESSION) {
      return { shouldWeaveQuestion: false, question: null, integrationHint: null };
    }

    // Filter out already-asked questions
    const availableQuestions = parentQuestions.filter(
      (q) => q.isActive && !this.questionsAskedThisSession.has(q.id),
    );

    if (availableQuestions.length === 0) {
      return { shouldWeaveQuestion: false, question: null, integrationHint: null };
    }

    // Get recent messages for topic detection
    const recentMessages = messages.slice(-4);
    const recentText = recentMessages.map((m) => m.textContent).join(' ');

    // Try to find a question that matches current conversation topics
    const topicMatch = this.findTopicMatch(availableQuestions, recentText);

    if (topicMatch) {
      this.questionsAskedThisSession.add(topicMatch.question.id);
      return {
        shouldWeaveQuestion: true,
        question: topicMatch.question,
        integrationHint: topicMatch.hint,
      };
    }

    // If no topic match, consider weaving based on timing and priority
    // Only do this after sufficient conversation turns
    if (conversationTurnCount >= MIN_TURNS_BEFORE_QUESTION * 2) {
      const highPriorityQuestion = availableQuestions.find((q) => q.priority >= 7);
      if (highPriorityQuestion) {
        this.questionsAskedThisSession.add(highPriorityQuestion.id);
        return {
          shouldWeaveQuestion: true,
          question: highPriorityQuestion,
          integrationHint: this.generateGenericHint(highPriorityQuestion),
        };
      }
    }

    return { shouldWeaveQuestion: false, question: null, integrationHint: null };
  }

  /**
   * Reset the session tracking (call when starting a new conversation).
   */
  resetSession(): void {
    this.questionsAskedThisSession.clear();
  }

  /**
   * Find a question whose topic matches the current conversation content.
   */
  private findTopicMatch(
    questions: ParentQuestion[],
    recentText: string,
  ): { question: ParentQuestion; hint: string } | null {
    const lowerText = recentText.toLowerCase();

    // Sort by priority (highest first)
    const sortedQuestions = [...questions].sort(
      (a, b) => b.priority - a.priority,
    );

    for (const question of sortedQuestions) {
      const topic = question.topic?.toLowerCase();

      // Check if the question's topic matches keywords in recent conversation
      if (topic && TOPIC_KEYWORDS[topic]) {
        const keywords = TOPIC_KEYWORDS[topic];
        const hasMatch = keywords.some((kw) => lowerText.includes(kw));
        if (hasMatch) {
          return {
            question,
            hint: this.generateTopicHint(question, topic),
          };
        }
      }

      // Also check if words from the question text appear in conversation
      const questionWords = question.questionText
        .toLowerCase()
        .split(/\s+/)
        .filter((w) => w.length > 3);
      const wordMatch = questionWords.some((w) => lowerText.includes(w));
      if (wordMatch) {
        return {
          question,
          hint: this.generateGenericHint(question),
        };
      }
    }

    return null;
  }

  /**
   * Generate a hint for weaving a topic-matched question.
   */
  private generateTopicHint(question: ParentQuestion, topic: string): string {
    return (
      `The child is talking about topics related to "${topic}". ` +
      `This is a natural moment to explore this parent question: "${question.questionText}". ` +
      `Weave this exploration naturally into your response without asking the question directly. ` +
      `Instead, use the current conversation topic as a bridge.`
    );
  }

  /**
   * Generate a generic hint for a high-priority question.
   */
  private generateGenericHint(question: ParentQuestion): string {
    return (
      `The parent has a high-priority question they'd like explored: "${question.questionText}". ` +
      `Find a gentle, natural way to steer the conversation toward this topic. ` +
      `Do not ask the question directly. Instead, share a related thought or ask a ` +
      `tangential question that might lead the child to share relevant information.`
    );
  }
}
