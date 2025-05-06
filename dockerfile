# Use Debian Slim base image
FROM debian:12.5-slim AS builder

# Metadata
LABEL maintainer="entroky@example.com" \
    org.opencontainers.image.title="Rapid Build Environment for entroky.github.io" \
    org.opencontainers.image.description="Optimized image for building entroky.github.io via Forester, TeX Live, and Bun"

# Set non-interactive mode for apt-get and environment variables
ARG DEBIAN_FRONTEND=noninteractive
ENV OPAMROOT="/root/.opam" \
    OPAMYES="true" \
    PATH="/root/.bun/bin:${OPAMROOT}/default/bin:${PATH}" \
    TERM="xterm-256color"

# Install base system dependencies, including tools for TeX Live and Just installation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    opam \
    git \
    m4 \
    unzip \
    pkg-config \
    libgmp-dev \
    ca-certificates \
    curl \
    wget \
    gnupg \
    # Minimal TeX Live base needed for tlmgr
    texlive-base \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Just (matching version from gh-pages.yml)
ARG JUST_VERSION=1.40.0
RUN curl -LSfs "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar -xzf - -C /usr/local/bin --strip-components=1 just

# Install Bun (matching version from gh-pages.yml)
ARG BUN_VERSION=1.1.29
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"

# Install Minimal TeX Live packages identified in gh-pages.yml
# Use --no-depends where appropriate if base packages provide functionality
# Adjust path if texlive installed elsewhere by base package
ENV PATH="/usr/bin:${PATH}"
RUN tlmgr option repository ctan && \
    tlmgr update --self && \
    tlmgr install \
    scheme-basic \
    amsmath amsfonts amssymb graphicx geometry ifthen xcolor hyperref float booktabs \
    enumerate xspace xpatch mathtools stmaryrd csquotes standalone microtype tools collection-latexrecommended \
    fontspec newpxtext newpxmath utfsym newunicodechar collection-fontsrecommended \
    listings \
    tikz pgfplots tikz-cd tikz-3dplot tkz-euclide contour dot2texi \
    algpseudocodex pseudo tabto tabularx \
    amsthm thmtools mdframed tcolorbox ntheorem \
    imakeidx cleveref backref makeindex bibtex \
    physics worldflags todonotes \
    xelatex \
    && tlmgr path add

# Initialize OPAM (matching OCaml version from gh-pages.yml)
# Disable sandboxing for CI environment
RUN opam init --disable-sandboxing --compiler=ocaml-base-compiler.5.3.0 --yes && \
    opam update

# Clone and Install Forester at the specific commit from gh-pages.yml
ARG FORESTER_COMMIT=56de06afe952d752c1a13fdcd8bb56c5fef9956f
RUN git clone https://git.sr.ht/~jonsterling/ocaml-forester /tmp/forester && \
    cd /tmp/forester && \
    git checkout ${FORESTER_COMMIT} && \
    opam pin add forester . --yes --no-action && \
    opam install forester --deps-only --yes && \
    opam install forester --yes && \
    # Clean up OPAM cache and source
    opam clean --logs --repo-cache --download-cache --switch-cleanup --unused-builds --safe --yes && \
    rm -rf /tmp/forester ${OPAMROOT}/download-cache/*

# Set working directory
WORKDIR /usr/src/app

# Copy package manifests and install Node dependencies
COPY package.json bun.lockb ./
# Install ALL dependencies including devDependencies as build scripts might use them (e.g., xslt3, biome)
# Use --frozen-lockfile for reproducible builds
RUN bun install --frozen-lockfile && \
    # Clean bun cache
    rm -rf /root/.bun/install/cache/*

# Copy the rest of the application code
COPY . .

# Ensure build scripts are executable
RUN chmod +x act.sh alias.sh bib.sh build.sh build_changed.sh chk.sh convert_xml.sh dev.sh ext.sh lize.sh lost.sh new.sh prep.sh thm.sh scripts/*.sh

# Set the default command to run the build via Just
CMD ["just", "build"]

# --- Final Image ---
# Create a smaller final image by copying only necessary artifacts
FROM debian:12.5-slim

# Install runtime dependencies (e.g., ca-certificates, potentially others if needed by bun runtime)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy necessary binaries and runtime files from the builder stage
COPY --from=builder /usr/local/bin/just /usr/local/bin/just
COPY --from=builder /root/.bun /root/.bun
COPY --from=builder ${OPAMROOT} ${OPAMROOT}
COPY --from=builder /usr/bin/forester /usr/bin/forester # Adjust path if needed
COPY --from=builder /usr/bin/opam /usr/bin/opam
COPY --from=builder /usr/bin/ocaml* /usr/bin/ # Copy OCaml runtime if needed separately
# Copy TeX Live runtime files (this can be complex and large) - Simplification: just copy the app + node_modules
# COPY --from=builder /usr/share/texlive /usr/share/texlive
# COPY --from=builder /usr/bin/xelatex /usr/bin/xelatex # etc.

# Set PATH for the final image
ENV OPAMROOT="/root/.opam" \
    PATH="/root/.bun/bin:${OPAMROOT}/default/bin:/usr/local/bin:/usr/bin:/bin" \
    TERM="xterm-256color"

WORKDIR /usr/src/app
COPY --from=builder /usr/src/app .

# Evaluate OPAM env vars in the final image
RUN eval $(opam env)

CMD ["just", "build"]