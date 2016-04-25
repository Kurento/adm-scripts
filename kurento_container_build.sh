#!/bin/bash -x

# This tool is intended to build Docker images
#
# PARAMETERS
#
# PUSH_IMAGES
#     Optional
#
#     yes if images should be pushed to registry
#     Either absent or any other value is considered false
#
# BUILD_ARGS
#     Optional
#     Build arguments to pass to docker build.
#     Format: NODE_VERSION=4.x JDK=jdk-8
#
# DOCKERFILE
#     Optional
#     Location of Dockerfile to build
#
# IMAGE_NAME
#     Optional
#     Name of image to build
#
# EXTRA_TAGS
#     Optional
#     Extra tags to apply to image


[ -n $PUSH_IMAGES ] || PUSH_IMAGES='no'

if [ "x$DOCKERFILE" != "x" ]; then
  FOLDER=$(dirname $DOCKERFILE)
else
  FOLDER=$PWD
fi

. parse_yaml.sh
eval $(parse_yaml $FOLDER/version.yml "")
commit=$(git rev-parse --short HEAD)

[ -n "$DOCKERFILE" ] || DOCKERFILE=./Dockerfile
[ -n "$IMAGE_NAME" ] || IMAGE_NAME=$image_name
[ -n "$TAG" ] || TAG=$image_version
echo "Extra tags: ${image_extra_tags[@]}"
[ -n "$EXTRA_TAGS" ] || EXTRA_TAGS="${image_extra_tags[@]}"

# If there's a generate.sh script, assume we need to dynamically generate the Dockerfile using it
# This is the case of selenium images
if [ -f generate.sh ]; then
  echo "Generating Dockerfile..."
  ./generate.sh $TAG
fi

# Build using a tag composed of the original tag and the short commit id
for BUILD_ARG in $BUILD_ARGS
do
  build_args+=("--build-arg $BUILD_ARG")
done
docker build --no-cache --rm=true ${build_args[@]} -t $IMAGE_NAME:${TAG}-${commit} -f $DOCKERFILE $FOLDER

# Tag the resulting image using the original tag
docker tag -f $IMAGE_NAME:${TAG}-${commit} $IMAGE_NAME:$TAG

# Apply any additional tags required
echo "Extra tags: $EXTRA_TAGS"
for EXTRA_TAG in $EXTRA_TAGS
do
  docker tag -f $IMAGE_NAME:$TAG-${commit} $IMAGE_NAME:$EXTRA_TAG
done

echo "### DOCKER IMAGES"
docker images

echo "#### SPACE AVAILABLE"
df -h

# Push
if [ "$PUSH_IMAGES" = "yes" ]; then
  docker login -u "$KURENTO_REGISTRY_USER" -p "$KURENTO_REGISTRY_PASSWD" -e "$KURENTO_EMAIL" $KURENTO_REGISTRY_URI
  docker tag -f $IMAGE_NAME:${TAG}-${commit} $KURENTO_REGISTRY_URI/$IMAGE_NAME:${TAG}-${commit}
  docker push $KURENTO_REGISTRY_URI/$IMAGE_NAME:${TAG}-${commit}

  docker tag -f $IMAGE_NAME:${TAG} $KURENTO_REGISTRY_URI/$IMAGE_NAME:$TAG
  docker push $KURENTO_REGISTRY_URI/$IMAGE_NAME:$TAG

  for EXTRA_TAG in $EXTRA_TAGS
  do
    docker tag -f $IMAGE_NAME:$EXTRA_TAG $KURENTO_REGISTRY_URI/$IMAGE_NAME:$EXTRA_TAG
    docker push $KURENTO_REGISTRY_URI/$IMAGE_NAME:$EXTRA_TAG
  done

  docker logout
fi