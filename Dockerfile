# syntax = docker/dockerfile:1.4

ARG NODE_VERSION=20.5.0-bullseye

# build assets & compile TypeScript

FROM --platform=$BUILDPLATFORM node:${NODE_VERSION} AS native-builder

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	rm -f /etc/apt/apt.conf.d/docker-clean \
	; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
	&& apt-get update \
	&& apt-get install -yqq --no-install-recommends \
	build-essential

RUN corepack enable

WORKDIR /misskey

COPY --link ["pnpm-lock.yaml", "pnpm-workspace.yaml", "package.json", "./"]
COPY --link ["scripts", "./scripts"]
COPY --link ["packages/backend/package.json", "./packages/backend/"]
COPY --link ["packages/frontend/package.json", "./packages/frontend/"]
COPY --link ["packages/sw/package.json", "./packages/sw/"]
COPY --link ["packages/misskey-js/package.json", "./packages/misskey-js/"]

RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
	pnpm i --frozen-lockfile --aggregate-output

COPY --link . ./

ARG NODE_ENV=production

RUN git submodule update --init
RUN pnpm build
RUN rm -rf .git/

# build native dependencies for target platform

FROM --platform=$TARGETPLATFORM node:${NODE_VERSION} AS target-builder

RUN apt-get update \
	&& apt-get install -yqq --no-install-recommends \
	build-essential

RUN corepack enable

WORKDIR /misskey

COPY --link ["pnpm-lock.yaml", "pnpm-workspace.yaml", "package.json", "./"]
COPY --link ["scripts", "./scripts"]
COPY --link ["packages/backend/package.json", "./packages/backend/"]

RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
	pnpm i --frozen-lockfile --aggregate-output

FROM --platform=$TARGETPLATFORM node:${NODE_VERSION}-slim AS runner

ARG UID="991"
ARG GID="991"

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	ffmpeg tini curl \
	&& corepack enable \
	&& groupadd -g "${GID}" misskey \
	&& useradd -l -u "${UID}" -g "${GID}" -m -d /misskey misskey \
	&& find / -type d -path /proc -prune -o -type f -perm /u+s -ignore_readdir_race -exec chmod u-s {} \; \
	&& find / -type d -path /proc -prune -o -type f -perm /g+s -ignore_readdir_race -exec chmod g-s {} \; \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists

USER misskey
WORKDIR /misskey

COPY --chown=misskey:misskey --from=target-builder /misskey/node_modules ./node_modules
COPY --chown=misskey:misskey --from=target-builder /misskey/packages/backend/node_modules ./packages/backend/node_modules
COPY --chown=misskey:misskey --from=native-builder /misskey/built ./built
COPY --chown=misskey:misskey --from=native-builder /misskey/packages/backend/built ./packages/backend/built
COPY --chown=misskey:misskey --from=native-builder /misskey/fluent-emojis /misskey/fluent-emojis
COPY --chown=misskey:misskey . ./

ENV NODE_ENV=production
HEALTHCHECK --interval=5s --retries=20 CMD ["/bin/bash", "/misskey/healthcheck.sh"]
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["pnpm", "run", "migrateandstart"]
