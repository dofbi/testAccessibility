# Lighthouse Site Auditor

Lighthouse Site Auditor is a tool for auditing websites using Google Lighthouse. It generates performance, accessibility, best practices, and SEO reports for each URL provided in a CSV file. The results are saved in both HTML and CSV formats.

## Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/dofbi/testAccessibility
    cd testAccessibility
    ```

2. Install dependencies:

    ```bash
    npm install
    ```

3. Install dependencies:

    ```bash
    sudo apt-get install jq
    ```

## Usage

To run the script, use the following command:

```bash
npm start --resources <resources_path> --reports <reports_path>
