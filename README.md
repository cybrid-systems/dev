# dev
A Docker-based, reproducible development environment for the Cybrid Systems/NovaSim project. Built on Ubuntu 24.04 with the latest LLVM/Clang toolchain.

## use Buildx
```bash
docker buildx create --use
```

## build and deploy

``` bash
docker buildx build -t ghcr.io/cybrid-systems/dev . --load
```


ubuntu24.04
```bash
docker buildx build --platform linux/amd64,linux/arm64 \
    -t ghcr.io/cybrid-systems/dev \
    . --push
```

## test

```bash
docker run -it --rm -v `pwd`/..:/root/code -w /root/code ghcr.io/cybrid-systems/dev /bin/zsh
```

## run

```bash
docker run --privileged -d -it --name angel -v `pwd`:/root/code -w /root/code ghcr.io/cybrid-systems/dev
docker exec -it --detach-keys="ctrl-z,z" angel /bin/zsh
git config --global user.name $your_name
git config --global user.email $your_email
```
