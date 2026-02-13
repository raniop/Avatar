/**
 * SafetyFilter provides content filtering for child safety.
 *
 * It checks both incoming child messages and outgoing avatar responses
 * for inappropriate content, and flags potential safety concerns.
 */

export interface SafetyCheckResult {
  isSafe: boolean;
  flags: SafetyFlag[];
  filteredContent?: string;
  severity: 'none' | 'low' | 'medium' | 'high' | 'critical';
}

export interface SafetyFlag {
  type: SafetyFlagType;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  matchedContent?: string;
}

export type SafetyFlagType =
  | 'INAPPROPRIATE_LANGUAGE'
  | 'VIOLENCE'
  | 'PERSONAL_INFO'
  | 'SELF_HARM'
  | 'ABUSE_DISCLOSURE'
  | 'ADULT_CONTENT'
  | 'BULLYING'
  | 'DANGEROUS_ACTIVITY'
  | 'EMOTIONAL_DISTRESS';

// Patterns for various safety concerns (case-insensitive)
const INAPPROPRIATE_LANGUAGE_PATTERNS = [
  /\b(shit|fuck|damn|hell|ass|bitch|crap|dick|bastard|piss)\b/i,
  /\b(stupid|idiot|dumb|loser|ugly|fat|hate\s+you)\b/i,
];

const VIOLENCE_PATTERNS = [
  /\b(kill|murder|stab|shoot|gun|knife|weapon|bomb|blood|die|dead)\b/i,
  /\b(hurt|punch|kick|beat|fight|attack|destroy|smash)\b/i,
];

const PERSONAL_INFO_PATTERNS = [
  /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/, // Phone numbers
  /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, // Email
  /\b\d{1,5}\s+[A-Za-z]+\s+(street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln)\b/i, // Addresses
  /\b(my address is|i live at|my school is|i go to)\b/i,
];

const SELF_HARM_PATTERNS = [
  /\b(kill myself|want to die|hurt myself|cut myself|suicide|don'?t want to live)\b/i,
  /\b(nobody loves me|everyone hates me|i'?m worthless|better off without me)\b/i,
];

const ABUSE_PATTERNS = [
  /\b(hit me|hits me|beats me|hurts me|touches me|scared of|afraid of)\b/i,
  /\b(mommy|daddy|parent|uncle|teacher|coach)\s+(hits|hurts|touches|scares)\b/i,
  /\b(don'?t tell anyone|keep it secret|not allowed to tell)\b/i,
];

const ADULT_CONTENT_PATTERNS = [
  /\b(sex|porn|naked|nude|breast|penis|vagina)\b/i,
  /\b(drugs|cocaine|marijuana|weed|meth|heroin|pills)\b/i,
  /\b(beer|wine|vodka|whiskey|drunk|alcohol|cigarette|smoke|vape)\b/i,
];

const EMOTIONAL_DISTRESS_PATTERNS = [
  /\b(i'?m\s+scared|i'?m\s+afraid|i'?m\s+sad|i'?m\s+lonely|i'?m\s+crying)\b/i,
  /\b(nightmare|can'?t sleep|bad dream|monster)\b/i,
  /\b(miss\s+(mommy|daddy|mom|dad)|parents\s+fighting|divorce)\b/i,
];

export class SafetyFilter {
  /**
   * Check child's incoming message for safety concerns.
   */
  checkChildMessage(text: string): SafetyCheckResult {
    const flags: SafetyFlag[] = [];

    // Check for self-harm indicators (critical priority)
    this.checkPatterns(text, SELF_HARM_PATTERNS, 'SELF_HARM', 'critical', flags);

    // Check for abuse disclosure (critical priority)
    this.checkPatterns(text, ABUSE_PATTERNS, 'ABUSE_DISCLOSURE', 'critical', flags);

    // Check for personal info sharing (high priority)
    this.checkPatterns(text, PERSONAL_INFO_PATTERNS, 'PERSONAL_INFO', 'high', flags);

    // Check for emotional distress (medium priority - not blocked, but flagged)
    this.checkPatterns(
      text,
      EMOTIONAL_DISTRESS_PATTERNS,
      'EMOTIONAL_DISTRESS',
      'medium',
      flags,
    );

    // Check for violence references (medium priority)
    this.checkPatterns(text, VIOLENCE_PATTERNS, 'VIOLENCE', 'medium', flags);

    // Check for inappropriate language (low priority)
    this.checkPatterns(
      text,
      INAPPROPRIATE_LANGUAGE_PATTERNS,
      'INAPPROPRIATE_LANGUAGE',
      'low',
      flags,
    );

    // Check for adult content (high priority)
    this.checkPatterns(text, ADULT_CONTENT_PATTERNS, 'ADULT_CONTENT', 'high', flags);

    const severity = this.computeOverallSeverity(flags);

    return {
      isSafe: severity !== 'critical',
      flags,
      severity,
    };
  }

  /**
   * Check avatar's outgoing response for safety compliance.
   * This is a secondary check to ensure the AI model hasn't generated
   * inappropriate content despite the system prompt constraints.
   */
  checkAvatarResponse(text: string): SafetyCheckResult {
    const flags: SafetyFlag[] = [];

    // Check for personal info in avatar response (should never happen)
    this.checkPatterns(text, PERSONAL_INFO_PATTERNS, 'PERSONAL_INFO', 'high', flags);

    // Check for violence in avatar response
    this.checkPatterns(text, VIOLENCE_PATTERNS, 'VIOLENCE', 'high', flags);

    // Check for inappropriate language
    this.checkPatterns(
      text,
      INAPPROPRIATE_LANGUAGE_PATTERNS,
      'INAPPROPRIATE_LANGUAGE',
      'high',
      flags,
    );

    // Check for adult content
    this.checkPatterns(text, ADULT_CONTENT_PATTERNS, 'ADULT_CONTENT', 'critical', flags);

    const severity = this.computeOverallSeverity(flags);

    return {
      isSafe: severity === 'none' || severity === 'low',
      flags,
      severity,
      filteredContent:
        severity === 'high' || severity === 'critical'
          ? this.getDefaultSafeResponse()
          : undefined,
    };
  }

  /**
   * Generate metadata flags for parent dashboard.
   */
  generateSafetyMetadata(
    flags: SafetyFlag[],
  ): Record<string, unknown> | undefined {
    if (flags.length === 0) return undefined;

    const metadata: Record<string, unknown> = {
      safetyFlags: flags.map((f) => ({
        type: f.type,
        severity: f.severity,
        description: f.description,
      })),
    };

    // Add urgent flags
    const criticalFlags = flags.filter((f) => f.severity === 'critical');
    if (criticalFlags.length > 0) {
      metadata.urgentAlerts = criticalFlags.map((f) => f.type);
    }

    return metadata;
  }

  /**
   * Check text against a set of patterns and add flags.
   */
  private checkPatterns(
    text: string,
    patterns: RegExp[],
    flagType: SafetyFlagType,
    severity: SafetyFlag['severity'],
    flags: SafetyFlag[],
  ): void {
    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        flags.push({
          type: flagType,
          description: this.getFlagDescription(flagType),
          severity,
          matchedContent: match[0],
        });
        break; // One flag per type is enough
      }
    }
  }

  /**
   * Compute the highest severity from all flags.
   */
  private computeOverallSeverity(
    flags: SafetyFlag[],
  ): SafetyCheckResult['severity'] {
    if (flags.length === 0) return 'none';

    const severityOrder: SafetyCheckResult['severity'][] = [
      'none',
      'low',
      'medium',
      'high',
      'critical',
    ];

    let maxIndex = 0;
    for (const flag of flags) {
      const index = severityOrder.indexOf(flag.severity);
      if (index > maxIndex) maxIndex = index;
    }

    return severityOrder[maxIndex];
  }

  /**
   * Get human-readable description for a safety flag type.
   */
  private getFlagDescription(type: SafetyFlagType): string {
    const descriptions: Record<SafetyFlagType, string> = {
      INAPPROPRIATE_LANGUAGE: 'Child used inappropriate or unkind language',
      VIOLENCE: 'Violence-related content detected',
      PERSONAL_INFO: 'Personal information shared or requested',
      SELF_HARM: 'Potential self-harm or suicidal ideation detected',
      ABUSE_DISCLOSURE: 'Possible abuse or neglect disclosure',
      ADULT_CONTENT: 'Adult or age-inappropriate content detected',
      BULLYING: 'Bullying behavior or language detected',
      DANGEROUS_ACTIVITY: 'Reference to dangerous activities',
      EMOTIONAL_DISTRESS: 'Child appears to be in emotional distress',
    };

    return descriptions[type];
  }

  /**
   * Get a safe default response when the AI-generated response fails safety checks.
   */
  private getDefaultSafeResponse(): string {
    const responses = [
      "That's an interesting thought! What else is on your mind today?",
      "Hmm, let's talk about something fun! What's your favorite thing to do?",
      "I love chatting with you! Tell me about something that made you smile today.",
      "You know what sounds fun? Let's play a word game! Can you think of an animal that starts with the letter B?",
    ];

    return responses[Math.floor(Math.random() * responses.length)];
  }
}
