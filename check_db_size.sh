psql -d backend_development -c "SELECT pg_size_pretty(pg_database_size(current_database()));"
