#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$PWD}"
features=""

add_feature() {
  features="$(append_unique_csv "$features" "$1")"
}

has_file() {
  [ -f "$ROOT/$1" ]
}

pkg_has_dep() {
  local pattern="$1"
  [ -f "$ROOT/package.json" ] || return 1
  search_file_regex "$pattern" "$ROOT/package.json"
}

tree_has() {
  local pattern="$1"
  search_project_tree_regex "$pattern" "$ROOT"
}

pkg_has_dep '"(next-auth|@auth/core|passport)"' && add_feature "auth"
pkg_has_dep '"(stripe|@stripe/[^"]+)"' && add_feature "stripe"
pkg_has_dep '"(@supabase/supabase-js|supabase)"' && add_feature "supabase"
pkg_has_dep '"(firebase|firebase-admin)"' && add_feature "firebase"
pkg_has_dep '"(@sentry/|bugsnag|rollbar)"' && add_feature "error-tracking"
pkg_has_dep '"(launchdarkly-js-client-sdk|@growthbook/growthbook|flagsmith|@unleash/proxy-client-sdk)"' && add_feature "feature-flags"
pkg_has_dep '"(bull|bullmq|agenda|bee-queue)"' && add_feature "background-jobs"
pkg_has_dep '"(socket.io-client|pusher-js|ably|socket.io)"' && add_feature "realtime"
pkg_has_dep '"(algoliasearch|typesense|instantsearch.js|meilisearch)"' && add_feature "search"
pkg_has_dep '"(multer|@aws-sdk/client-s3|image_picker|file_picker)"' && add_feature "uploads"
pkg_has_dep '"(nodemailer|resend|@sendgrid/mail|postmark)"' && add_feature "email"
pkg_has_dep '"(expo-notifications|firebase_messaging|web-push)"' && add_feature "push"
pkg_has_dep '"(@react-native-community/netinfo|connectivity_plus)"' && add_feature "offline-sync"
pkg_has_dep '"(hls.js|video.js|@mux/mux-player-react)"' && add_feature "video"
pkg_has_dep '"(ioredis|node-cache|cache_manager)"' && add_feature "caching"
pkg_has_dep '"(@prisma/client|drizzle-orm|typeorm|sequelize|mongoose)"' && add_feature "database-orm"
pkg_has_dep '"(axios-retry|p-retry|opossum|cockatiel)"' && add_feature "resilience"
pkg_has_dep '"(graphql|@apollo/server|@apollo/client|graphql-yoga)"' && add_feature "graphql"
pkg_has_dep '"(kafkajs|amqplib|@google-cloud/pubsub|nats|@aws-sdk/client-sqs)"' && add_feature "message-queue"
pkg_has_dep '"(@opentelemetry/sdk-node|dd-trace|@newrelic/|elastic-apm-node)"' && add_feature "observability"
pkg_has_dep '"(express-rate-limit|rate-limiter-flexible|@nestjs/throttler)"' && add_feature "rate-limiting"
pkg_has_dep '"(recharts|chart.js|@nivo/|@tremor/react|victory)"' && add_feature "reporting"
pkg_has_dep '"(zustand|@reduxjs/toolkit|mobx|jotai|recoil|pinia)"' && add_feature "state-management"
pkg_has_dep '"(react-hook-form|formik|final-form)"' && add_feature "forms"
pkg_has_dep '"(framer-motion|@react-spring/web|gsap|@motionone/react)"' && add_feature "motion"
pkg_has_dep '"(three|@react-three/fiber|lottie-web|lottie-react|cannon-es|ogl|regl)"' && add_feature "advanced-animation"
pkg_has_dep '"(class-variance-authority|@radix-ui/react-|@storybook/react|@storybook/vue3)"' && add_feature "design-system"
pkg_has_dep '"(tailwindcss|@tailwindcss/|tailwind-merge|tailwind-variants)"' && add_feature "tailwind"
pkg_has_dep '"(class-variance-authority|tailwind-variants)"' && add_feature "variants"
pkg_has_dep '"(@radix-ui/react-|lucide-react)"' && add_feature "ui-primitives"
pkg_has_dep '"(i18next|react-intl|next-intl|@angular/localize|flutter_localizations)"' && add_feature "i18n"
pkg_has_dep '"(posthog-js|mixpanel|@amplitude/analytics|@segment/analytics-next)"' && add_feature "analytics"

if has_file public/manifest.json || has_file manifest.json || tree_has 'service-worker|workbox|next-pwa|vite-plugin-pwa'; then
  add_feature "pwa"
fi

if tree_has 'darkMode|prefers-color-scheme|dark:'; then
  add_feature "dark-mode"
fi

if tree_has 'className=.*(rounded-|px-|py-|text-|bg-|border-|flex|grid)' || tree_has '@tailwind|@apply'; then
  add_feature "utility-classes"
fi

if [ -z "$features" ]; then
  printf 'none\n'
else
  printf '%s\n' "$features"
fi
