# Noot Not Frontend

An anonymous confession sharing platform built with React, TypeScript, and Material-UI.

## Features

- 🎭 Anonymous confession sharing
- 👍👎 Vote on confessions (upvote/downvote)
- 🚨 Report inappropriate content
- 📱 Responsive design with dark/light theme
- 🔄 Real-time data synchronization with API
- 🛡️ Content moderation integration

## Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- Running noot-not-api backend service

## Installation

1. Install dependencies:

```bash
npm install
```

2. Create environment file:

```bash
cp .env.example .env
```

3. Configure environment variables in `.env`:

```env
# API Configuration
VITE_API_BASE_URL=http://localhost:8000/api
```

## Development

Start the development server:

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## API Integration

The frontend integrates with the noot-not-api backend through the following endpoints:

### Authentication

- No authentication required (anonymous platform)

### Endpoints Used

- `POST /api/confessions` - Create new confession
- `GET /api/confessions` - List confessions with pagination
- `POST /api/confessions/{id}/vote` - Vote on confession
- `POST /api/confessions/{id}/report` - Report confession

### Data Flow

1. **Create Confession**: Content is submitted to API for moderation before display
2. **List Confessions**: Fetched from API with pagination support
3. **Voting**: Votes are sent to API and local state is updated optimistically
4. **Reporting**: Reports are sent to API and confession is marked locally

### Error Handling

- API errors are displayed to users with retry options
- Fallback to localStorage for offline functionality
- Optimistic UI updates with rollback on error

## Features

### Confession Management

- Character limit validation (500 characters)
- Real-time character counter
- Content moderation integration
- Automatic timestamp handling

### Voting System

- Upvote/downvote functionality
- Vote state persistence across sessions
- Visual feedback for user votes
- Vote count display

### Reporting System

- One-click reporting for inappropriate content
- Report state persistence
- Visual indicators for reported content

### UI/UX

- Material-UI components
- Dark/light theme toggle
- Responsive design
- Loading states and error handling
- Optimistic updates
- Smooth animations

## Configuration

### Environment Variables

- `VITE_API_BASE_URL`: Backend API base URL (default: http://localhost:8000/api)

### API Timeout

- Default timeout: 10 seconds
- Configurable in `src/services/api.ts`

## Error Handling

The application handles various error scenarios:

1. **Network Errors**: Show retry options and offline indicators
2. **API Errors**: Display error messages from backend
3. **Validation Errors**: Client-side validation with immediate feedback
4. **Content Moderation**: Handle rejected content gracefully

## Local Storage

The app uses localStorage for:

- User vote history
- Reported confessions list
- Theme preferences
- Fallback data when API is unavailable

## Building for Production

```bash
npm run build
```

The built files will be in the `dist` directory.

## Development Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Tech Stack

- **React 19** - UI library
- **TypeScript** - Type safety
- **Material-UI (MUI)** - Component library
- **Axios** - HTTP client
- **Vite** - Build tool
- **ESLint** - Code linting

## API Data Types

```typescript
interface ApiConfession {
  id: string;
  content: string;
  moderation_status: "approved" | "pending" | "rejected";
  upvotes: number;
  downvotes: number;
  reports: number;
  created_at: string;
  updated_at: string;
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is open source and available under the MIT License.
