<template>
  <div v-if="message" class="status">{{ message }}</div>
</template>

<script setup lang="ts">
defineProps<{ message: string }>();
</script>
