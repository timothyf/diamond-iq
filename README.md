# shopify-prep-project

This project uses:

- **Ruby on Rails** backend in `/tmp/workspace/timothyf/shopify-prep-project/backend`
- **PostgreSQL** for the Rails database (`backend/config/database.yml`)
- **Vue.js** frontend in `/tmp/workspace/timothyf/shopify-prep-project/frontend`
- **RuboCop** linter for backend code (`bundle exec rubocop`)

## Quick start

### Backend (Rails + PostgreSQL)

```bash
cd /tmp/workspace/timothyf/shopify-prep-project/backend
bundle install
bin/rails db:prepare
bin/rails server
```

### Frontend (Vue)

```bash
cd /tmp/workspace/timothyf/shopify-prep-project/frontend
npm install
npm run dev
```
