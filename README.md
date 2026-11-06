# dev

Ubuntu 26.10 image with the packages required to build Aura. Published as `ghcr.io/cybrid-systems/aura-ci:v0.1.0`. It does not replace `ghcr.io/cybrid-systems/dev`, which Aura CI still pins. GCC 16.2, CMake 4.5.0-rc3, Ninja 1.13.2, mold, libgit2, and LLVM 23.1.5 trimmed to the binaries and static libraries the Aura build links (`clang`, `clang-format`, `clang-tidy`, `llvm-cov`, `llvm-profdata`, `llvm-symbolizer`, `ld.lld`, and `core orcjit native nativecodegen mc`).

Not in the image: Emacs, Node, pnpm, Rust, OpenClaw, Flang, MLIR, LLDB. A build needs about 15GB of temporary disk while the LLVM tarball is unpacked. Unused files are deleted in that same `RUN`.

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
    -t ghcr.io/cybrid-systems/aura-ci:v0.1.0 \
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
  -t ghcr.io/cybrid-systems/aura-ci:v0.1.0
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
  --net host \
  --cap-add=SYS_PTRACE \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  -v $(pwd):/home/dev/code \
  -w /home/dev/code \
  ghcr.io/cybrid-systems/aura-ci:latest

docker exec -u root angel chown -R dev:dev /home/dev
docker exec -it -u dev angel /bin/zsh -l
```
