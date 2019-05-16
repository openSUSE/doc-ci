# Docker Image susedoc/mini-ci

1. Go into this directory.

2. Run:

   ```
   docker build ./
   ```

3. Tag the image and upload it:

   ```
   docker tag IMAGE_ID susedoc/mini-ci:openSUSE-42.3
   docker push susedoc/mini-ci:openSUSE-42.3
   ```

