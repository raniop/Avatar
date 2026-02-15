import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const missionTemplates = [
  {
    theme: 'space_adventure',
    titleEn: 'Space Adventure',
    titleHe: 'הרפתקה בחלל',
    descriptionEn: 'Blast off to the stars and explore the galaxy!',
    descriptionHe: 'טסים לכוכבים וחוקרים את הגלקסיה!',
    narrativePrompt: `You and the child are astronauts on a spaceship exploring the galaxy.
Start by describing the amazing view from the spaceship window - stars, planets, and nebulas.
Ask the child what planet they want to visit first and what they think they'll find there.
Use space themes to naturally explore feelings: "When astronauts are far from home, they sometimes miss their family. Do you ever feel that way?"
Encourage imagination and wonder while gently exploring the child's emotional world.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'space_bg',
    avatarCostumeKey: 'astronaut',
    interests: ['Space', 'Science', 'Robots'],
    sortOrder: 1,
  },
  {
    theme: 'underwater_explorer',
    titleEn: 'Underwater Explorer',
    titleHe: 'חוקר מתחת למים',
    descriptionEn: 'Dive deep into the ocean and discover sea creatures!',
    descriptionHe: 'צוללים לעומק האוקיינוס ומגלים יצורי ים!',
    narrativePrompt: `You and the child are deep-sea explorers in a submarine.
Describe colorful coral reefs, friendly dolphins, and mysterious caves.
Ask the child what sea creature they'd like to be friends with and why.
Use ocean themes to explore emotions: "Some fish swim in big groups because they feel safer together. Do you have friends who make you feel safe?"
Create a calm, magical atmosphere while exploring the child's social world.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'ocean_bg',
    avatarCostumeKey: 'diver',
    interests: ['Ocean Life', 'Swimming', 'Nature', 'Animals'],
    sortOrder: 2,
  },
  {
    theme: 'magical_forest',
    titleEn: 'Magical Forest',
    titleHe: 'היער הקסום',
    descriptionEn: 'Enter the enchanted forest and meet magical creatures!',
    descriptionHe: 'נכנסים ליער הקסום ופוגשים יצורים מופלאים!',
    narrativePrompt: `You and the child are walking through a magical forest where animals can talk.
Describe glowing mushrooms, fairy lights, and friendly woodland creatures.
Ask the child to help you find a lost baby animal and return it to its family.
Use the journey to explore feelings: "The baby bunny misses its mommy. Have you ever missed someone? What did you do?"
Build empathy and emotional vocabulary through the adventure.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'forest_bg',
    avatarCostumeKey: 'explorer',
    interests: ['Nature', 'Animals', 'Gardening'],
    sortOrder: 3,
  },
  {
    theme: 'dinosaur_world',
    titleEn: 'Dinosaur World',
    titleHe: 'עולם הדינוזאורים',
    descriptionEn: 'Travel back in time to meet real dinosaurs!',
    descriptionHe: 'נוסעים אחורה בזמן לפגוש דינוזאורים אמיתיים!',
    narrativePrompt: `You and the child have traveled back in time to the age of dinosaurs!
Describe massive, gentle herbivores eating leaves and baby dinosaurs playing.
Ask the child which dinosaur they'd like to ride and where they'd go.
Use dinosaur themes to explore bravery: "Even the biggest T-Rex was scared sometimes. What makes you feel brave? What scares you a little?"
Normalize fears while celebrating courage.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'dino_bg',
    avatarCostumeKey: 'explorer',
    interests: ['Dinosaurs', 'Science', 'Nature', 'Animals'],
    sortOrder: 4,
  },
  {
    theme: 'superhero_training',
    titleEn: 'Superhero Training',
    titleHe: 'אימון גיבורי על',
    descriptionEn: 'Train to become a superhero with special powers!',
    descriptionHe: 'מתאמנים להיות גיבורי על עם כוחות מיוחדים!',
    narrativePrompt: `You and the child are at superhero training school!
Each superhero gets to choose their special power. Ask the child what power they'd pick.
Create fun "training exercises" like flying practice and shield making.
Use superhero themes to explore strengths: "Every superhero has something they're really good at AND something they're still learning. What are you really good at?"
Build self-esteem while exploring challenges.`,
    ageRangeMin: 4,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'hero_bg',
    avatarCostumeKey: 'superhero',
    interests: ['Superheroes', 'Martial Arts', 'Running', 'Gymnastics'],
    sortOrder: 5,
  },
  {
    theme: 'cooking_adventure',
    titleEn: 'Cooking Adventure',
    titleHe: 'הרפתקת בישול',
    descriptionEn: 'Cook magical recipes in a fantastical kitchen!',
    descriptionHe: 'מבשלים מתכונים קסומים במטבח פנטסטי!',
    narrativePrompt: `You and the child are chefs in a magical kitchen where food comes alive!
Describe a kitchen with flying ingredients, talking fruits, and rainbow ovens.
Ask the child what magical dish they want to create and what ingredients they'd use.
Use cooking themes to explore family: "Who in your family loves to eat? What does your family eat together? Do you help in the kitchen at home?"
Create a warm, nurturing atmosphere while exploring family dynamics.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'kitchen_bg',
    avatarCostumeKey: 'chef',
    interests: ['Cooking', 'Crafts'],
    sortOrder: 6,
  },
  {
    theme: 'pirate_treasure',
    titleEn: 'Pirate Treasure Hunt',
    titleHe: 'ציד אוצרות פיראטים',
    descriptionEn: 'Set sail and find the hidden treasure!',
    descriptionHe: 'מפליגים למצוא את האוצר הנסתר!',
    narrativePrompt: `You and the child are pirates sailing the seven seas looking for treasure!
Describe your pirate ship, the waves, and a treasure map with clues.
Ask the child what treasure they hope to find and who they'd share it with.
Use pirate themes to explore sharing and friendship: "Pirates need a good crew they can trust. Who do you trust the most? Who are your best friends?"
Explore social relationships and sharing in a fun adventure context.`,
    ageRangeMin: 4,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'pirate_bg',
    avatarCostumeKey: 'pirate',
    interests: ['Pirates', 'Ocean Life', 'Swimming'],
    sortOrder: 7,
  },
  {
    theme: 'fairy_tale',
    titleEn: 'Fairy Tale Kingdom',
    titleHe: 'ממלכת האגדות',
    descriptionEn: 'Visit a kingdom where fairy tales come to life!',
    descriptionHe: 'מבקרים בממלכה שבה אגדות מתעוררות לחיים!',
    narrativePrompt: `You and the child have entered a magical fairy tale kingdom!
Describe castles, friendly dragons, and magical gardens.
Let the child choose if they want to be a prince/princess, a knight, or a wizard.
Use fairy tale themes to explore wishes and dreams: "If you had three wishes, what would you wish for? What makes you happiest in the whole world?"
Explore dreams, desires, and happiness through storytelling.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'castle_bg',
    avatarCostumeKey: 'royal',
    interests: ['Fairy Tales', 'Princesses', 'Reading', 'Theater'],
    sortOrder: 8,
  },
  {
    theme: 'animal_rescue',
    titleEn: 'Animal Rescue',
    titleHe: 'הצלת חיות',
    descriptionEn: 'Help rescue and care for animals in need!',
    descriptionHe: 'עוזרים להציל ולטפל בחיות שזקוקות לעזרה!',
    narrativePrompt: `You and the child run an animal rescue center!
Describe adorable animals that need help - a puppy with a hurt paw, a kitten who's lost.
Ask the child how they would help each animal and what name they'd give them.
Use caregiving themes to explore empathy: "The little puppy looks sad. How do you think it feels? Have you ever felt sad and someone helped you feel better?"
Build empathy, compassion, and emotional recognition.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'rescue_bg',
    avatarCostumeKey: 'vet',
    interests: ['Animals', 'Nature', 'Gardening'],
    sortOrder: 9,
  },
  {
    theme: 'rainbow_land',
    titleEn: 'Rainbow Land',
    titleHe: 'ארץ הקשת',
    descriptionEn: 'Explore a colorful world made of rainbows!',
    descriptionHe: 'חוקרים עולם צבעוני עשוי קשתות!',
    narrativePrompt: `You and the child are in Rainbow Land where everything is made of colors!
Each color represents a feeling - red is exciting, blue is calm, yellow is happy, purple is creative.
Ask the child what color they feel like today and why.
Use colors to explore emotions: "If your day was a color, what color would it be? What happened that made you feel that way?"
This is a gentle, creative way to help children express their emotional state.`,
    ageRangeMin: 3,
    ageRangeMax: 12,
    durationMinutes: 5,
    sceneryAssetKey: 'rainbow_bg',
    avatarCostumeKey: 'painter',
    interests: ['Drawing', 'Crafts', 'Music', 'Dancing'],
    sortOrder: 10,
  },
];

async function main() {
  console.log('🌱 Seeding database...');

  // Clear existing mission templates
  await prisma.missionTemplate.deleteMany();

  // Create mission templates
  for (const template of missionTemplates) {
    await prisma.missionTemplate.create({
      data: template,
    });
    console.log(`  ✅ Created mission: ${template.titleEn}`);
  }

  console.log(`\n🎉 Seeded ${missionTemplates.length} mission templates!`);
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
