<!--
SPDX-FileCopyrightText: syuilo and other misskey contributors
SPDX-License-Identifier: AGPL-3.0-only
-->

<template>
<div>
	<MkPagination v-slot="{items}" ref="list" :pagination="type === 'following' ? followingPagination : followersPagination">
		<div :class="$style.users">
			<MkUserInfo v-for="user in items.map(x => type === 'following' ? x.followee : x.follower)" :key="user.id" :user="user"/>
		</div>
	</MkPagination>
</div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import * as misskey from 'misskey-js';
import MkUserInfo from '@/components/MkUserInfo.vue';
import MkPagination from '@/components/MkPagination.vue';

const props = defineProps<{
	user: misskey.entities.User;
	type: 'following' | 'followers';
}>();

const followingPagination = {
	endpoint: 'users/following' as const,
	limit: 20,
	params: computed(() => ({
		userId: props.user.id,
	})),
};

const followersPagination = {
	endpoint: 'users/followers' as const,
	limit: 20,
	params: computed(() => ({
		userId: props.user.id,
	})),
};
</script>

<style lang="scss" module>
.users {
	display: grid;
	grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
	grid-gap: var(--margin);
}
</style>
