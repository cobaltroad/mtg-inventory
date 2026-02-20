# Discord OAuth Implementation Roadmap

## Overview

Implement Discord as an OAuth 2.0 provider to replace the current seeded default user system. This will enable proper multi-user authentication.

## Current State

- Single seeded default user in `backend/db/seeds.rb`
- No authentication middleware
- `ApplicationController#current_user` returns seeded user unconditionally

## Implementation Phases

### Phase 1: Backend Setup (Week 1)

#### 1.1 Add OAuth Dependencies

```ruby
# Gemfile
gem 'omniauth'
gem 'omniauth-discord'
gem 'oauth2'
```

#### 1.2 Configure OmniAuth

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord, 
    ENV['DISCORD_CLIENT_ID'], 
    ENV['DISCORD_CLIENT_SECRET'],
    scope: 'identify email'
end
```

#### 1.3 Create OAuth Models

- Create `oauth_providers` table to store provider links
- Add `provider`, `uid`, `user_id` columns to track Discord associations

```bash
rails g model OauthProvider provider:string uid:string user:references
```

#### 1.4 Update User Model

- Add `password_digest` (for potential future local auth) or make password optional
- Add Devise or implement session-based auth

#### 1.5 Create Auth Routes

```ruby
# config/routes.rb
get '/auth/discord', to: 'auth#discord'
get '/auth/discord/callback', to: 'auth#callback'
post '/auth/logout', to: 'auth#logout'
get '/auth/status', to: 'auth#status'
```

### Phase 2: Backend Controllers (Week 1-2)

#### 2.1 Create Auth Controller

```ruby
# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  def discord
    redirect_to DiscordOAuth2Client.auth_code.authorize_url(
      redirect_uri: ENV['DISCORD_REDIRECT_URI'],
      scope: 'identify email'
    )
  end

  def callback
    token = DiscordOAuth2Client.auth_code.get_token(
      params[:code],
      redirect_uri: ENV['DISCORD_REDIRECT_URI']
    )
    
    user_info = token.get('https://discord.com/api/users/@me')
    
    user = User.find_or_create_by_discord(user_info.parsed)
    session[:user_id] = user.id
    
    redirect_to frontend_url
  end

  def logout
    session.delete(:user_id)
    redirect_to frontend_url
  end
end
```

#### 2.2 Update ApplicationController

```ruby
def current_user
  return nil if session[:user_id].nil?
  @current_user ||= User.find_by(id: session[:user_id])
end
```

#### 2.3 API Authentication

- Create `authenticate_api_user` before_action for API endpoints
- Use session-based auth or API tokens for SPA

### Phase 3: Frontend Integration (Week 2)

#### 3.1 Add Login Button

```svelte
<!-- src/routes/login/+page.svelte -->
<script lang="ts">
  import { base } from '$app/paths';
  
  function loginWithDiscord() {
    window.location.href = `${base}/api/auth/discord`;
  }
</script>

<button on:click={loginWithDiscord}>
  Login with Discord
</button>
```

#### 3.2 Handle Callback

```svelte
<!-- src/routes/auth/callback/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  onMount(async () => {
    const response = await fetch(`${base}/api/auth/status`);
    if (response.ok) {
      goto('/inventory');
    } else {
      goto('/login');
    }
  });
</script>
```

#### 3.3 Auth State Management

- Create Svelte store for auth state
- Implement session refresh mechanism

### Phase 4: Production Configuration (Week 2)

#### 4.1 Discord Developer Portal

1. Create application at https://discord.com/developers/applications
2. Add redirect URI: `https://yourdomain.com/api/auth/discord/callback`
3. Generate client ID and secret
4. Add to production environment variables

#### 4.2 Environment Variables

```bash
# .env.production
DISCORD_CLIENT_ID=your_client_id
DISCORD_CLIENT_SECRET=your_client_secret
DISCORD_REDIRECT_URI=https://yourdomain.com/api/auth/discord/callback
```

#### 4.3 Production-Specific Config

```ruby
# config/environments/production.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord, 
    ENV['DISCORD_CLIENT_ID'], 
    ENV['DISCORD_CLIENT_SECRET'],
    scope: 'identify email',
    callback_path: '/api/auth/discord/callback'
end
```

### Phase 5: Data Migration (Week 3)

#### 5.1 Migrate Existing Inventory

```ruby
# After first login, migrate seeded data
class AuthController < ApplicationController
  def callback
    # ... existing code ...
    
    if user.collection_items.empty? && OauthProvider.exists?(user: user)
      # Migrate seeded items to new user
      migrate_seeded_inventory(user)
    end
  end
end
```

#### 5.2 Deprecate Seeded User

- Mark seeded user for deprecation
- Provide migration path for existing data

## Environment Variables Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DISCORD_CLIENT_ID` | Discord app client ID | `123456789` |
| `DISCORD_CLIENT_SECRET` | Discord app client secret | `abc123...` |
| `DISCORD_REDIRECT_URI` | OAuth callback URL | `https://domain/api/auth/discord/callback` |

## Discord OAuth Flow

```
┌──────────┐                              ┌─────────┐                              ┌──────────┐
│  User    │                              │Frontend │                              │  Backend │
└────┬─────┘                              └────┬────┘                              └────┬─────┘
     │                                           │                                      │
     │  1. Click "Login with Discord"            │                                      │
     │───────────────────────────────────────────>                                      │
     │                                           │                                      │
     │                                           │  2. GET /api/auth/discord            │
     │                                           │───────────────────────────────────────>│
     │                                           │                                      │
     │                                           │  3. Redirect to Discord OAuth        │
     │                                           │<───────────────────────────────────────│
     │                                           │                                      │
     │  4. User authorizes app                  │                                      │
     │───────────────────────────────────────────>                                      │
     │                                           │                                      │
     │                                           │  5. Redirect to callback with code   │
     │                                           │<───────────────────────────────────────│
     │                                           │                                      │
     │                                           │  6. POST /api/auth/discord/callback  │
     │                                           │───────────────────────────────────────>│
     │                                           │                                      │
     │                                           │  7. Exchange code for token, fetch   │
     │                                           │     user info, create session        │
     │                                           │<───────────────────────────────────────│
     │                                           │                                      │
     │  8. Redirect to app                       │                                      │
     │<───────────────────────────────────────────                                      │
```

## Testing Checklist

- [ ] OAuth flow completes successfully
- [ ] New users can register via Discord
- [ ] Returning users log in correctly
- [ ] Session persists across page refreshes
- [ ] Logout clears session
- [ ] Invalid/expired sessions redirect to login
- [ ] Rate limiting on auth endpoints
- [ ] Error handling for Discord API failures

## Security Considerations

1. **State parameter** - Implement CSRF protection with state parameter
2. **Scope validation** - Verify requested scopes match configured scopes
3. **Token storage** - Never store Discord tokens; use session-only
4. **Redirect URI validation** - Whitelist allowed redirect URIs
5. **Rate limiting** - Prevent brute-force on auth endpoints

## Rollback Plan

If issues arise:
1. Revert to seeded user by modifying `current_user` fallback
2. Keep OAuth routes but require admin approval
3. Use feature flag to toggle between auth systems
