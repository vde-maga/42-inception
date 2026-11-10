DC = docker compose -f srcs/docker-compose.yml

.PHONY: all up down re clean fclean

all: up

up:
	$(DC) up -d --build

down:
	$(DC) down

clean:
	$(DC) down

fclean:
	$(DC) down --rmi local -v

re: fclean up
