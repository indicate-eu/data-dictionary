# INDICATE Data Dictionary Contribution Guide

## About INDICATE

INDICATE (INfrastructure for Data-driven Innovation in Critical carE) is a pan-European federated data infrastructure for ICU data that enables cross-border healthcare research while maintaining data sovereignty. The project connects 15+ ICU institutions across multiple European countries.

**Key Principles:**
- Patient data never leaves hospitals
- Federated architecture with distributed computation
- Open collaboration and community-driven development
- Full regulatory compliance (GDPR, EHDS, NIS2D, AI Act)

## About This Application

The INDICATE Data Dictionary is an R Shiny application that provides an interactive interface to explore the INDICATE Minimal Data Dictionary - a consensus-based collection of standardized clinical concepts designed to harmonize ICU data across Europe.

## What You Can Contribute

### Collaborative Development

- Dictionary content (general concepts, mappings)
- UI/UX improvements
- Bug fixes and performance optimizations
- Documentation and guides
- Translations and internationalization
- Testing and quality assurance

### Not Included Here

- Infrastructure as Code for INDICATE central services (managed separately)
- Study packages and research code (follow separate governance process)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

1. Signed the appropriate agreement (Consortium or Accession Agreement) as an organization
2. Access to INDICATE GitHub repositories (via B2B invitation)
3. Completed INDICATE user onboarding
4. Set up your development environment

### Development Setup

```bash
# 1. Clone the repository
git clone https://github.com/indicate-eu/data-dictionary.git
cd data-dictionary

# 2. Install dependencies
R -e "install.packages('devtools')"
R -e "devtools::install_deps()"

# 3. Run the application
R -e "devtools::load_all(); indicate::run_app()"
```

### Quick Start

```bash
# 1. Create a feature branch
git checkout -b feature/brief-description

# 2. Make your changes
# ... edit files ...

# 3. Test locally
R -e "devtools::load_all(); indicate::run_app()"
R -e "devtools::check()"

# 4. Commit and push
git add .
git commit -m "feat: brief description of changes"
git push origin feature/brief-description

# 5. Create a Pull Request on GitHub
```

## How to Contribute

### 1. Create a Branch

Use descriptive branch names:
- `feature/[description]` - New features
- `bugfix/[description]` - Bug fixes
- `docs/[description]` - Documentation updates

### 2. Make Your Changes

Follow these guidelines:
- Write clear, readable R code
- Follow the Shiny module pattern (`mod_*_ui`, `mod_*_server`)
- Add roxygen2 comments for functions
- Update documentation as needed

### 3. Commit Your Work

Use clear commit messages:
```
type(scope): brief description

- Detailed explanation if needed
- Link to requirements: REQ###
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 4. Create a Pull Request

When creating a PR:
1. Fill in the pull request template
2. Link to related requirements (REQ###) if applicable
3. Describe what you changed and why
4. Request review from appropriate team members

## Code Standards

### R Code Style

Follow tidyverse style guide:

```r
# Use snake_case for variables and functions
calculate_statistics <- function(patient_data, values) {
  # Process patient data according to OMOP CDM
  #
  # @param patient_data Data frame with patient information
  # @param values Numeric vector of measurement values
  #
  # @return Processed data frame

  result <- patient_data %>%
    filter(!is.na(value)) %>%
    summarise(mean_value = mean(values))

  return(result)
}
```

### Shiny Module Pattern

```r
# UI function
mod_example_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # UI elements here
  )
}

# Server function
mod_example_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    # Server logic here
  })
}
```

### General Rules

- Use meaningful variable names
- Follow the existing code structure
- Document public functions with roxygen2
- Use `observe_event()` wrapper (not `observeEvent()`)

## Security Requirements

### Never Commit

- Passwords or API keys
- Personal data or PII
- Connection strings with credentials
- Private certificates

### Always Do

- Check dependencies for vulnerabilities
- Add license headers to new files
- Review data files for sensitive information

## Licensing

All contributions must be licensed under:

**European Union Public License (EUPL) v1.2**

Add this header to new R files:

```r
# Copyright (c) 2025 [Your Organization]
# Licensed under the EUPL-1.2
# See: https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
```

## Review Process

### What Reviewers Check

- Functionality works correctly
- Code follows R/Shiny standards
- Application runs without errors
- Documentation is updated
- No security issues
- Requirements are linked (if applicable)

### Timeline

- Initial review: Within 10 business days
- Follow-up reviews: Within 5 business days
- Urgent changes: Tag as `urgent` for priority

## Getting Help

### Documentation

- [INDICATE Project](https://indicate-europe.eu)
- [R Shiny Documentation](https://shiny.posit.co/)
- [OMOP CDM](https://ohdsi.github.io/CommonDataModel/)

### Support

**General questions:** info@indicate-europe.eu

## Common Questions

**Q: How do I link my code to requirements?**

Add comments in your code:
```r
# Implements: REQ015 - Central Metadata Catalog
# Related: AD014 - Knowledge Repository Approach
```

**Q: My app works locally but fails in Docker. Why?**

Check for:
- File path differences (use `system.file()` for package resources)
- Environment variables (INDICATE_ENV, INDICATE_APP_FOLDER)
- Missing dependencies in DESCRIPTION

**Q: Can I use a third-party R package?**

Yes, if:
- License is EUPL-compatible (Apache, MIT, GPL, BSD)
- No known security vulnerabilities
- Listed in DESCRIPTION under Imports or Suggests

**Q: How do I request a new feature?**

1. Create a GitHub issue
2. Describe the feature and use case
3. Tag with `enhancement`
4. Discuss with the team

## Troubleshooting

### Build Failures

```bash
# Clear package cache and reinstall
R -e "remove.packages('indicate')"
R -e "devtools::install_deps()"
R -e "devtools::load_all()"
```

### Permission Issues

Contact your repository administrator if:
- Can't push to your branch
- Can't create pull requests
- Missing from GitHub team

## Repository Structure

```
data-dictionary/
├── R/                     # R source code
│   ├── app_ui.R          # Main UI
│   ├── app_server.R      # Main server
│   ├── mod_*.R           # Shiny modules
│   ├── fct_*.R           # Function libraries
│   └── utils_*.R         # Utility functions
├── inst/
│   ├── extdata/csv/      # CSV data files
│   └── www/              # Web assets (CSS, JS)
├── man/                   # R documentation
├── tests/                 # Test files
├── .github/              # GitHub workflows
├── DESCRIPTION           # Package metadata
└── NAMESPACE             # R namespace
```

## Thank You!

Thank you for contributing to INDICATE! Your work helps advance European healthcare research while maintaining the highest standards of data protection and patient privacy.

---

**Questions?** Contact the INDICATE team at info@indicate-europe.eu

**License:** European Union Public License v1.2
**Copyright:** 2025 INDICATE Consortium

*This project has received funding from the European Union's Digital Europe Programme.*
