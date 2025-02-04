# Firebase App Hosting Setup Checklist

- [x] **Install the Firebase CLI**  
  Visit the [Firebase CLI documentation](https://firebase.google.com/docs/cli) and follow instructions to install or update to the latest version.

- [x] **Create/Configure a Firebase project**  
  1. Go to the [Firebase console](https://firebase.google.com/) and create a new project (or select an existing one).  
  2. Ensure you have the **Blaze** pricing plan if needed for advanced usage.

- [ ] **Initialize Hosting**  
  1. In your project folder, run `firebase init hosting`  
  2. Choose your Firebase project  
  3. Specify the public directory (e.g., `build` for a web app build folder)  
  4. Configure your build output if you're using a framework like Next.js or Angular

- [ ] **Set up GitHub integration (Optional but recommended)**  
  1. Authorize the [Firebase GitHub app](https://firebase.google.com/docs/app-hosting#how-does-it-work) on your repository  
  2. In the Firebase console or via CLI, connect your GitHub repository for automatic deployments

- [ ] **Build your app (if applicable)**  
  1. For single-page apps, run your build commands (e.g., `npm run build` or `yarn build`).  
  2. Make sure the build artifacts go to the folder specified during Firebase Hosting init.

- [ ] **Deploy**  
  Run `firebase deploy --only hosting` to push your build to Firebase Hosting.

---

### Warnings
- Make sure to check your **project billing plan** before using advanced features.  
- Always consider your **app's environment variables** or secrets before deploying publicly.  
- If you're using **google-services.json**, ensure it's **excluded from version control**.  

---

**References**  
- [Firebase Docs - Quickstart for Hosting](https://firebase.google.com/docs/hosting/quickstart?authuser=0)  
- [Firebase Docs - App Hosting Overview](https://firebase.google.com/docs/app-hosting) 