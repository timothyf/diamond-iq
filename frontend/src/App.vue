<template>
  <header class="app-bar">
    <RouterLink class="app-brand" to="/">
      <span class="app-brand__mark">DIQ</span>
      <span>
        <strong>DiamondIQ</strong>
        <small>Baseball intelligence</small>
      </span>
    </RouterLink>
    <nav aria-label="Primary navigation">
      <RouterLink to="/">Stat board</RouterLink>
      <RouterLink to="/admin">Admin</RouterLink>
    </nav>
  </header>
  <RouterView />
</template>
