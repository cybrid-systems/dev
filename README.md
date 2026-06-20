# dev
A Docker-based, reproducible development environment for the Cybrid Systems/NovaSim project. Built on Ubuntu 26.04 with the latest LLVM/Clang toolchain.

## use Buildx
```bash
docker buildx create --use
```

orbstack
``` bash
docker buildx create --name orb-multi \
  --driver docker-container \
  --use \
  --bootstrap
```

## build and deploy

build
``` bash
docker buildx build --platform linux/arm64 -t ghcr.io/cybrid-systems/aura-ci:arm64 . --load
docker buildx build --platform linux/amd64 -t ghcr.io/cybrid-systems/aura-ci:amd64 . --load
```

deploy both
```bash
docker buildx build --platform linux/amd64,linux/arm64 \
    -t ghcr.io/cybrid-systems/aura-ci \
    -t ghcr.io/cybrid-systems/aura-ci:v1.0.1 \
    . --push
```

deploy arm64

``` bash
docker buildx build \
  --platform linux/arm64 \
  -t ghcr.io/cybrid-systems/aura-ci:arm64 \
  --push .
```

deploy amd64

``` bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/cybrid-systems/aura-ci:amd64 \
  --push .
```

deploy merge

``` bash
docker buildx imagetools create \
  ghcr.io/cybrid-systems/aura-ci:amd64 \
  ghcr.io/cybrid-systems/aura-ci:arm64 \
  -t ghcr.io/cybrid-systems/aura-ci:latest \
  -t ghcr.io/cybrid-systems/aura-ci:v1.0.0
```

inspect
``` bash
docker buildx imagetools inspect ghcr.io/cybrid-systems/aura-ci:latest
```

or
``` bash
docker manifest inspect ghcr.io/cybrid-systems/aura-ci:latest
```

## test

```bash
docker run -it --rm -v `pwd`/..:/root/code -w /root/code ghcr.io/cybrid-systems/aura-ci /bin/zsh
```

``` bash
./test-image.sh
```

## run

```bash
docker run --privileged -d -it --name angel -v `pwd`:/root/code -w /root/code ghcr.io/cybrid-systems/aura-ci
docker exec -it --detach-keys="ctrl-z,z" angel /bin/zsh
git config --global user.name $your_name
git config --global user.email $your_email
```

``` bash
docker run -d -it --name angel \
  --cap-add=SYS_PTRACE \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  -p 18789:18789 \
  -p 18791:18791 \
  -v $(pwd):/home/dev/code \
  -w /home/dev/code \
  ghcr.io/cybrid-systems/aura-ci:latest

docker exec -it -u dev angel /bin/zsh -l
```

## openclaw

```bash
pnpm add -g openclaw@2026.6.1
openclaw onboard
openclaw config set gateway.bind lan
openclaw config set agents.defaults.workspace ~/code/workspace
echo "ghp_*" > ~/.github-token
openclaw gateway
```
