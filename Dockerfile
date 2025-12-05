FROM r-base:4.4.2

LABEL maintainer="Boris Delange <boris.delange@univ-rennes.fr>"

# Install system dependencies required for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure Shiny to listen on all interfaces at port 7860 (Hugging Face default)
# Use Posit Package Manager for binary packages (much faster installation)
RUN mkdir -p /usr/local/lib/R/etc && \
    echo "options(shiny.port=7860, shiny.host='0.0.0.0')" >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/bookworm/latest'))" >> /usr/local/lib/R/etc/Rprofile.site

# Install R package dependencies (using binary packages from Posit Package Manager)
RUN R -e "install.packages(c(\
  'shiny',\
  'shiny.router',\
  'DT',\
  'DBI',\
  'RSQLite',\
  'duckdb',\
  'rappdirs',\
  'dplyr',\
  'magrittr',\
  'purrr',\
  'readxl',\
  'readr',\
  'htmltools',\
  'htmlwidgets',\
  'shinycssloaders',\
  'shinyAce',\
  'shinyjs',\
  'bcrypt',\
  'visNetwork',\
  'remotes'\
), repos = 'https://packagemanager.posit.co/cran/__linux__/bookworm/latest')"

# Copy the package source code
COPY . /app/indicate

# Install the indicate package from local source
RUN R -e "remotes::install_local('/app/indicate', dependencies = FALSE)"

# Set environment variable to indicate container deployment
ENV INDICATE_ENV=docker

# Expose port 7860 for the Shiny application (Hugging Face default)
EXPOSE 7860

# Run the application with explicit host/port settings
CMD ["R", "-e", "indicate::run_app(options = list(host = '0.0.0.0', port = 7860, launch.browser = FALSE))"]
