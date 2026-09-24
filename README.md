# pythia.software

The public website for [pythia.software](https://pythia.software). It is a
static site hosted on Firebase Hosting in the `pythia-mail` GCP project, using
the dedicated `pythia-software` Hosting site.

## Run locally

```sh
./run.sh
```

The script finds an available port beginning at 8000, starts a local server,
and opens it in a browser.

## Build

```sh
./build.sh
```

`build.sh` generates the standalone HTML pages in `.site-build/`. `index.html`
is the shared site shell; page content lives in `site/pages/`. This keeps the
deployed site fully static while allowing every page to reuse the same theme,
controls, decorative fabric, and footer.

The Mail Manager privacy policy and terms are generated as `privacy.html` and
`terms.html`. Firebase Hosting serves them at `/privacy` and `/terms` through
same-site rewrites. Before deploying changes to either policy, have the service
owner confirm the effective date and obtain legal approval. The owner has
confirmed that the provider list is Google Cloud/Firebase, Neon, and Twilio,
with no additional analytics or marketing recipients, and that deletion
requests go to info@pythia.software for manual review. The policy and SMS
program cover only xplo Tech Blog and Pythia startup announcements. Before
registration, the Mail Manager app must prevent Grady publication texts from
using this SMS sender or campaign; those publications are outside these pages.

## Deploy

Install the Firebase CLI and authenticate once:

```sh
npm install --global firebase-tools
firebase login
```

Then deploy:

```sh
./deploy.sh
```

The deployment script runs `build.sh`, stages only the generated public assets
in the ignored `.firebase-public` directory, and deploys the `pythia-software`
target. It does not deploy or modify the existing `pythia-mail` Hosting site used by
`mail.pythia.software`.

The live Firebase endpoint is <https://pythia-software.web.app>. The custom
domain is <https://pythia.software>.

### Authentication

The `pythia-mail` organization policy prohibits long-lived service-account
keys. Local deploys use the authenticated Firebase CLI account. Automated
deploys should use Google Application Default Credentials with Workload
Identity Federation or service-account impersonation, not a JSON key.

### DNS

The custom domain is configured through Firebase Hosting. Its apex web records
point to Firebase; mail-related MX/TXT records and the `mail.pythia.software`
subdomain are independent and must remain unchanged.
