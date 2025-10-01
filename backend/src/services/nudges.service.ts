import { StreaksService } from './streaks.service';
import { EventsService } from './events.service';

export class NudgesService {
  private streaksService: StreaksService;
  private eventsService: EventsService;

  constructor() {
    this.streaksService = new StreaksService();
    this.eventsService = new EventsService();
  }

  async generateNudges(userId: string) {
    const streaks = await this.streaksService.getStreakSummary(userId);
    const patterns = await this.eventsService.getPatterns(userId);

    const nudges: any[] = [];

    // Example: risk of streak loss
    if (streaks.overall < 3) {
      nudges.push({
        type: 'low_streak',
        title: 'Pick It Up',
        message: 'Your streaks are running cold. Hit a habit today and reignite momentum.',
        priority: 'high',
      });
    }

    // Example: recurring pattern
    if (patterns['habit_missed']) {
      nudges.push({
        type: 'pattern_break',
        title: 'Break the Pattern',
        message: `We see you’ve missed ${patterns['habit_missed']} habits recently. Time to flip the script.`,
        priority: 'medium',
      });
    }

    return nudges;
  }
}
