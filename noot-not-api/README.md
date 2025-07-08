# Noot Not API

Anonymous confessions API with content moderation.

## Setup

1. Install dependencies:

```bash
composer install
```

2. Copy environment file:

```bash
cp .env.example .env
```

3. Configure your database in `.env`

4. Run migrations:

```bash
composer run migrate
```

5. Start the server:

```bash
composer run start
```

## API Endpoints

- `POST /api/confessions` - Submit a new confession
- `GET /api/confessions` - Get paginated confessions
- `POST /api/confessions/{id}/vote` - Vote on a confession (upvote/downvote)
- `POST /api/confessions/{id}/report` - Report a confession

## Environment Variables

- `DB_HOST` - Database host
- `DB_PORT` - Database port
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `OPENAI_API_KEY` - OpenAI API key for content moderation
