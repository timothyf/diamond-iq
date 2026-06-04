# shopify-prep-project

This project uses:

- **Ruby on Rails** backend in `/shopify-prep-project/backend`
- **PostgreSQL** for the Rails database (`backend/config/database.yml`)
- **Vue.js** frontend in `/shopify-prep-project/frontend`
- **RuboCop** linter for backend code (`bundle exec rubocop`)

## Quick start

### Backend (Rails + PostgreSQL)

```bash
cd /shopify-prep-project/backend
bundle install
bin/rails db:prepare
bin/rails server
```

### Frontend (Vue)

```bash
cd /shopify-prep-project/frontend
npm install
npm run dev
```
