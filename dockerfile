# Use Debian Slim base image (matches ubuntu-22.04 closely enough for most packages)
FROM debian:12.5-slim

# Metadata
LABEL maintainer="entroky@example.com" \
    org.opencontainers.image.title="Rapid Build Environment for entroky.github.io" \
    org.opencontainers.image.description="Optimized image for building entroky.github.io via Forester, TeX Live, and Bun"

# Set non-interactive mode for apt-get and environment variables
ARG DEBIAN_FRONTEND=noninteractive
ENV OPAMROOT="/root/.opam" \
    OPAMYES="true" \
    PATH="/root/.bun/bin:${OPAMROOT}/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/texlive/bin/linux" \
    TERM="xterm-256color" \
    # Set TEXINPUTS globally in the container, matching build.sh logic
    TEXINPUTS=".:/usr/src/app/tex/:"

# Install base system dependencies, including tools for TeX Live and Just installation
# Added wget and gnupg for tlmgr setup
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
    perl \
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

# Install Minimal TeX Live packages identified in gh-pages.yml using tlmgr
# Using a profile for potentially smaller install footprint
RUN wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar -xzf install-tl-unx.tar.gz && \
    cd install-tl-*/ && \
    # Create a minimal profile
    echo "selected_scheme scheme-minimal" > texlive.profile && \
    echo "TEXDIR /usr/local/texlive" >> texlive.profile && \
    echo "TEXMFLOCAL /usr/local/texlive/texmf-local" >> texlive.profile && \
    echo "TEXMFSYSVAR /usr/local/texlive/texmf-var" >> texlive.profile && \
    echo "TEXMFSYSCONFIG /usr/local/texlive/texmf-config" >> texlive.profile && \
    echo "instopt_adjustpath 1" >> texlive.profile && \
    echo "instopt_adjustrepo 1" >> texlive.profile && \
    echo "tlpdbopt_autobackup 0" >> texlive.profile && \
    echo "tlpdbopt_install_docfiles 0" >> texlive.profile && \
    echo "tlpdbopt_install_srcfiles 0" >> texlive.profile && \
    # Install using the profile
    ./install-tl --profile=texlive.profile && \
    cd .. && rm -rf install-tl-* install-tl-unx.tar.gz && \
    # Add TeX Live bin to PATH explicitly for subsequent RUN commands
    export PATH="/usr/local/texlive/bin/linux:${PATH}" && \
    # Install specific packages
    tlmgr option repository ctan && \
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
    # Add any packages potentially missed by scheme-basic but needed by the above
    latex-bin \
    luatex \
    context \
    # Clean up tlmgr cache
    && rm -rf /usr/local/texlive/texmf-var/web2c/tlmgr.log /tmp/install-tl* /root/.texlive*

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

# Evaluate OPAM environment variables to make them available
RUN eval $(opam env)

# Set the default command to run the build via Just
CMD ["just", "build"]
