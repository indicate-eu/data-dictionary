FROM rocker/tidyverse:4.4.2

LABEL maintainer="Boris Delange <boris.delange@univ-rennes.fr>"

# Install system dependencies for R packages and Python for huggingface_hub
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install huggingface_hub to download datasets
RUN pip3 install --break-system-packages huggingface_hub

# Configure Shiny to listen on all interfaces at port 7860 (Hugging Face default)
# Use Posit Package Manager for binary packages (much faster installation)
RUN mkdir -p /usr/local/lib/R/etc && \
    echo "options(shiny.port=7860, shiny.host='0.0.0.0')" >> /usr/local/lib/R/etc/Rprofile.site && \
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

# Create directory for OHDSI vocabularies in /root/indicate_files/ohdsi
RUN mkdir -p /root/indicate_files/ohdsi

# Create startup script that downloads vocabularies at runtime then starts app
RUN echo '#!/bin/bash\n\
if [ -n "$HF_TOKEN" ]; then\n\
    echo "Downloading OHDSI vocabularies from Hugging Face..."\n\
    python3 -c "import os; from huggingface_hub import hf_hub_download; token=os.environ.get(\"HF_TOKEN\"); d=\"/root/indicate_files/ohdsi\"; \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"CONCEPT.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"CONCEPT_ANCESTOR.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"CONCEPT_CLASS.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"CONCEPT_RELATIONSHIP.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"CONCEPT_SYNONYM.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"DOMAIN.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"DRUG_STRENGTH.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"RELATIONSHIP.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"VOCABULARY.csv\", repo_type=\"dataset\", local_dir=d, token=token); \
hf_hub_download(repo_id=\"indicate-eu/ohdsi-vocabularies\", filename=\"vocabularies.duckdb\", repo_type=\"dataset\", local_dir=\"/root/indicate_files\", token=token)"\n\
    echo "Download complete."\n\
else\n\
    echo "HF_TOKEN not set, skipping vocabulary download."\n\
fi\n\
exec R -e "indicate::run_app(options = list(host = \"0.0.0.0\", port = 7860, launch.browser = FALSE))"' > /start.sh && chmod +x /start.sh

# Expose port 7860 for the Shiny application (Hugging Face default)
EXPOSE 7860

# Run startup script
CMD ["/start.sh"]
