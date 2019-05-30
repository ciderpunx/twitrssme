# Running TwitRSS.me with Docker

A Dockerfile and docker-compose.yml have been created to run TwitRSS.me under Docker. All you need is a working Docker installation, and optionally Docker Compose.

## Step 0: Install docker

Refer to https://docs.docker.com/install/ for installing Docker.

## Step 1: Build an image

We'll use `twitrssme` as the image name, but you can use any legal image name here.

  `docker build -t twitrssme .`

The first time through this will take a little while.

## Step 2: Run the container

This command will start the container in the foreground, listening on port 3000.

  `docker run --rm --port 3000:80 twitrssme`

To run it in the background, add the `--detach` flag.

  `docker run --rm --detach --port 3000:80 twitrssme`

That's all you need. Your TwitRSS.me server will be available on http://localhost:3000/ .

# Running TwitRSS.me with Docker Compose

A `docker-compose.yml` is provided which mounts the local directory to `/var/www/twitrssme` in the container. This is handy for development as any local changes are available immediately in the running container, with no image rebuild neessary.

To start TwitRSS.me in Docker Compose, use:

  `docker-compose up`

Docker Compose will build the image if necessary, and then run the container.

As before, your TwitRSS.me server will be available on http://localhost:3000/ .
