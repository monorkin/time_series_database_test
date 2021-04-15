```
# docker-benchmark --no-teardown --verbose

# Run benchmark and keep data
docker-compose exec app ./benchmark --no-teardown --verbose

# Run benchamrk and don't generate tables or data
docker-compose exec app ./benchmark --no-prepare --no-teardown --verbose

# Erase all data
docker-compose exec app ./benchmark --no-prepare --skip-tests --verbose
```
