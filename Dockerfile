FROM rocker/tidyverse:4.4.2

LABEL maintainer="Boris Delange <boris.delange@univ-rennes.fr>"

# Install system dependencies for R packages
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure Shiny to listen on all interfaces at port 3838
# Use Posit Package Manager for binary packages (much faster installation)
RUN mkdir -p /usr/local/lib/R/etc && \
    echo "options(shiny.port=3838, shiny.host='0.0.0.0')" >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(shiny.maxRequestSize = 5000 * 1024^2)" >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest'))" >> /usr/local/lib/R/etc/Rprofile.site

# Install R package dependencies (tidyverse packages already included in base image)
RUN R -e "install.packages(c(\
  'shiny',\
  'shiny.router',\
  'DT',\
  'RSQLite',\
  'duckdb',\
  'rappdirs',\
  'shinycssloaders',\
  'shinyAce',\
  'shinyjs',\
  'bcrypt',\
  'visNetwork'\
), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')"

# Copy the package source code
COPY . /app/indicate

# Install the indicate package from local source
RUN R -e "remotes::install_local('/app/indicate', dependencies = FALSE)"

# Create directory for OHDSI vocabularies
RUN mkdir -p /root/indicate_files/ohdsi

# Set environment variable to indicate Docker environment
ENV INDICATE_ENV=docker

# Expose port 3838 for the Shiny application
EXPOSE 3838

# Run the application
CMD ["R", "-e", "indicate::run_app(options = list(host = '0.0.0.0', port = 3838, launch.browser = FALSE))"]
