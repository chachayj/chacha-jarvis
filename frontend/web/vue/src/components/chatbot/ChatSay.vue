<template>
  <div v-if="text" class="say">{{ text }}</div>
</template>

<script setup lang="ts">
defineProps<{ text: string }>();
</script>
