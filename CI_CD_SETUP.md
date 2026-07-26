# CI/CD Setup — Great Note

Pipeline: [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

- **CI** (analyze + test + smoke build) runs on every push/PR to `main`.
- **Deploy** runs only when you push a version tag:
  ```bash
  git tag v2.5.1
  git push origin v2.5.1
  ```
  → Android AAB → **Play internal** track, iOS IPA → **TestFlight**.
  You then promote to production manually in each console.

Version name comes from the tag (`v2.5.1` → `2.5.1`); build number is the git
commit count (always increasing, so stores never reject a duplicate).

---

## 0. 🔴 ROTATE THESE FIRST (they were committed to a public repo)

They are still in git history. Untracking them does not un-expose them.

| Secret | Action |
|---|---|
| Google Play service account (`google_service_account.json`) | Google Cloud → IAM → Service Accounts → **delete the key**, create a new JSON key |
| App Store Connect API key (`88M9PZQQVA.p8`) | App Store Connect → Users and Access → Integrations → **Revoke**, create a new key |
| Android upload keystore password (`android/key.properties`) | Rotate the password (keystore file itself was not committed) |
| `MATCH_PASSWORD` (in `ios/fastlane/.env`) | Re-run `fastlane match` with a new passphrase (see §4) |

Optional but recommended: purge them from history with
[`git filter-repo`](https://github.com/newren/git-filter-repo) or BFG, then
force-push. Rotation is the real fix; history purge is cleanup.

---

## 1. Google Play (Android)

1. Play Console → **Setup → API access** → link a Google Cloud project.
2. In Google Cloud → create a **service account** → create a **JSON key** → download.
3. Enable **Google Play Android Developer API** in that GCP project.
4. Play Console → **Users & permissions** → invite the service-account email →
   grant **Release to testing tracks** (at least) for this app.
5. The app must have had **one manual upload** to the internal track already
   (Google requires the track to exist before API uploads).

## 2. App Store Connect (iOS)

1. App record exists for `com.johncolani.infiniteNotesPlus` ✔️
2. Users and Access → **Integrations → App Store Connect API** → generate a key
   with **App Manager** role → download the `.p8` (once). Note **Key ID** + **Issuer ID**.

## 3. Android signing secrets

Base64-encode your **upload keystore** (`.jks`):
```bash
base64 -i /path/to/upload-keystore.jks | pbcopy   # macOS
```

## 4. iOS signing via fastlane match (one-time, local)

1. Create a **private** GitHub repo, e.g. `johnacolani/app-certificates`.
2. From `ios/`, run once locally (generates + stores certs/profiles encrypted):
   ```bash
   cd ios
   MATCH_GIT_URL=https://github.com/johnacolani/app-certificates.git \
   bundle exec fastlane match appstore
   ```
   Choose a strong passphrase → that becomes `MATCH_PASSWORD`.
3. For CI repo access, create a fine-grained PAT with read/write to the certs
   repo and set `MATCH_GIT_BASIC_AUTHORIZATION` = `base64("username:PAT")`:
   ```bash
   echo -n "johnacolani:ghp_xxx" | base64
   ```

---

## 5. GitHub repository secrets to add

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of the upload `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | full contents of the new service-account JSON |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_P8_BASE64` | base64 of the new `.p8` |
| `MATCH_GIT_URL` | https URL of the certificates repo |
| `MATCH_PASSWORD` | match passphrase |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64("user:PAT") for the certs repo |

---

## 6. Cutting a release

```bash
# make sure main is green, then:
git tag v2.5.1
git push origin v2.5.1
```

Watch the run in the **Actions** tab. When it's green:
- **TestFlight** → the build appears under your app; add testers / submit for review.
- **Play internal** → the release is live on the internal track; promote to
  production in Play Console when ready.
