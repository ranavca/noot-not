# Setup Instructions

## Prerequisites

1. **PHP 8.1+**: Make sure you have PHP 8.1 or higher installed
2. **PostgreSQL**: Install and set up a PostgreSQL database
3. **Composer**: Install Composer for PHP dependency management

### Installing Composer (if not installed)

On macOS:

```bash
# Using Homebrew
brew install composer

# Or download directly
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### Installing PostgreSQL (if not installed)

On macOS:

```bash
# Using Homebrew
brew install postgresql
brew services start postgresql

# Create a database
createdb confessions_db
```

## Project Setup

1. **Install dependencies:**

```bash
composer install
```

2. **Configure environment:**

```bash
cp .env.example .env
```

Edit `.env` with your database credentials and OpenAI API key:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=confessions_db
DB_USER=your_username
DB_PASSWORD=your_password
OPENAI_API_KEY=your_openai_api_key
```

3. **Run database migrations:**

```bash
composer run migrate
```

4. **Start the development server:**

```bash
composer run start
```

The API will be available at `http://localhost:8000`

## Testing

Run the test suite:

```bash
./vendor/bin/phpunit
```

## API Testing

You can test the API endpoints using curl:

```bash
# Health check
curl http://localhost:8000/health

# Create a confession
curl -X POST http://localhost:8000/api/confessions \
  -H "Content-Type: application/json" \
  -d '{"content":"This is my anonymous confession..."}'

# Get confessions
curl http://localhost:8000/api/confessions

# Vote on a confession (replace {id} with actual ID)
curl -X POST http://localhost:8000/api/confessions/{id}/vote \
  -H "Content-Type: application/json" \
  -d '{"type":"upvote"}'

# Report a confession
curl -X POST http://localhost:8000/api/confessions/{id}/report
```
