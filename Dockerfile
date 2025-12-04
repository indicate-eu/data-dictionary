FROM r-base:4.4.2

LABEL maintainer="Boris Delange <boris.delange@univ-rennes.fr>"

# Install system dependencies required for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure Shiny to listen on all interfaces at port 3838
RUN echo "\noptions(shiny.port=3838, shiny.host='0.0.0.0')" >> /usr/local/lib/R/etc/Rprofile.site

# Install R package dependencies
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
  'remotes'\
))"

# Copy the package source code
COPY . /app/indicate

# Install the indicate package from local source
RUN R -e "remotes::install_local('/app/indicate', dependencies = FALSE)"

# Expose port 3838 for the Shiny application
EXPOSE 3838

# Run the application
CMD ["R", "-e", "indicate::run_app()"]
