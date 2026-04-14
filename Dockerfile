FROM us-central1-docker.pkg.dev/ucb-datahub-2018/base-images-repo/base-r-image:c25cdff

USER root
RUN apt-get update && apt-get install -y tini && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# System packages
# ------------------------------------------------------------
# Copy your new apt.txt
COPY apt.txt /tmp/apt.txt

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends $(grep -v '^#' /tmp/apt.txt) && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/apt.txt

ENV SHINY_SERVER_URL=https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-1.5.23.1030-amd64.deb
RUN curl --silent --location --fail ${SHINY_SERVER_URL} > /tmp/shiny-server.deb && \
    apt install --no-install-recommends --yes /tmp/shiny-server.deb && \
    rm /tmp/shiny-server.deb

# google-chrome is for pagedown; chromium doesn't work nicely with it (snap?)
RUN wget --quiet -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update > /dev/null && \
    apt-get -qq install /tmp/chrome.deb > /dev/null && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /tmp/chrome.deb

# ------------------------------------------------------------
# Conda / Python packages
# ------------------------------------------------------------
# Copy environment.yml for additional packages
USER ${NB_USER}
COPY --chown=${NB_USER}:${NB_USER} environment.yml /tmp/environment.yml


# Update existing /srv/conda/notebook environment with new packages
RUN mamba env update -n notebook -f /tmp/environment.yml && \
    mamba clean -afy && rm -rf /tmp/environment.yml

# Prepare VS Code extensions
USER root
ENV VSCODE_EXTENSIONS=${CONDA_DIR}/share/code-server/extensions
RUN install -d -o ${NB_USER} -g ${NB_USER} ${VSCODE_EXTENSIONS} && \
    chown ${NB_USER}:${NB_USER} ${CONDA_DIR}/share/code-server

USER ${NB_USER}

COPY extensions/ /tmp/extensions/

RUN set -euo pipefail; \
    CS="${CONDA_DIR}/bin/code-server"; \
    EXT_DIR="${VSCODE_EXTENSIONS}"; \
    \
    $CS --extensions-dir "$EXT_DIR" --install-extension /tmp/extensions/ms-toolsai.jupyter.vsix; \
    $CS --extensions-dir "$EXT_DIR" --install-extension /tmp/extensions/ms-python.python.vsix; \
    $CS --extensions-dir "$EXT_DIR" --install-extension /tmp/extensions/quarto.quarto.vsix; \
    \
    rm -rf /tmp/extensions

USER root
RUN rm -rf /tmp/*

ENV REPO_DIR=/srv/repo
COPY --chown=${NB_USER}:${NB_USER} image-tests ${REPO_DIR}/image-tests

USER ${NB_USER}
WORKDIR /home/${NB_USER}

COPY install.R /tmp/install.R
RUN r /tmp/install.R

COPY file-locks /etc/rstudio/file-locks

RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds

EXPOSE 8888
ENTRYPOINT ["tini", "--"]
