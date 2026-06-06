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



### Stats

Batting Stats

playerId
teamAbbrev
teamName
positionAbbrev
gamesPlayed
plateAppearances
atBats
runs
hits
doubles
triples
homeRuns
rbi
baseOnBalls
intentionalWalks
strikeOuts
stolenBases
caughtStealing
avg
obp
slg
ops
totalBases
hitByPitch
sacBunts
sacFlies
groundIntoDoublePlay
groundOuts
airOuts
leftOnBase
atBatsPerHomeRun
babip
source_url
age
ballsInPlay
catchersInterference
caughtStealingPercentage
extraBaseHits
flyHits
flyOuts
gidp
gidpOpp
groundHits
groundOutsToAirouts
homeRunsPerPlateAppearance
iso
leagueId
leagueName
lineHits
lineOuts
numberOfPitches
pitchesPerPlateAppearance
playerFirstName
playerFullName
playerInitLastName
playerLastName
playerUseName
popHits
popOuts
position
primaryPositionAbbrev
rank
reachedOnError
stolenBasePercentage
strikeoutsPerPlateAppearance
swingAndMisses
teamId
teamShortName
totalSwings
type
walkOffs
walksPerPlateAppearance
walksPerStrikeout
year
