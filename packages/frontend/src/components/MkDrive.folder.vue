<!--
SPDX-FileCopyrightText: syuilo and other misskey contributors
SPDX-License-Identifier: AGPL-3.0-only
-->

<template>
<div
	:class="[$style.root, { [$style.draghover]: draghover }]"
	draggable="true"
	:title="title"
	@click="onClick"
	@contextmenu.stop="onContextmenu"
	@mouseover="onMouseover"
	@mouseout="onMouseout"
	@dragover.prevent.stop="onDragover"
	@dragenter.prevent="onDragenter"
	@dragleave="onDragleave"
	@drop.prevent.stop="onDrop"
	@dragstart="onDragstart"
	@dragend="onDragend"
>
	<p :class="$style.name">
		<template v-if="hover"><i :class="$style.icon" class="ti ti-folder ti-fw"></i></template>
		<template v-if="!hover"><i :class="$style.icon" class="ti ti-folder ti-fw"></i></template>
		{{ folder.name }}
	</p>
	<p v-if="defaultStore.state.uploadFolder == folder.id" :class="$style.upload">
		{{ i18n.ts.uploadFolder }}
	</p>
	<button v-if="selectMode" class="_button" :class="[$style.checkbox, { [$style.checked]: isSelected }]" @click.prevent.stop="checkboxClicked"></button>
</div>
</template>

<script lang="ts" setup>
import { computed, defineAsyncComponent, ref } from 'vue';
import * as Misskey from 'misskey-js';
import * as os from '@/os';
import { i18n } from '@/i18n';
import { defaultStore } from '@/store';
import { claimAchievement } from '@/scripts/achievements';
import copyToClipboard from '@/scripts/copy-to-clipboard';

const props = withDefaults(defineProps<{
	folder: Misskey.entities.DriveFolder;
	isSelected?: boolean;
	selectMode?: boolean;
}>(), {
	isSelected: false,
	selectMode: false,
});

const emit = defineEmits<{
	(ev: 'chosen', v: Misskey.entities.DriveFolder): void;
	(ev: 'move', v: Misskey.entities.DriveFolder): void;
	(ev: 'upload', file: File, folder: Misskey.entities.DriveFolder);
	(ev: 'removeFile', v: Misskey.entities.DriveFile['id']): void;
	(ev: 'removeFolder', v: Misskey.entities.DriveFolder['id']): void;
	(ev: 'dragstart'): void;
	(ev: 'dragend'): void;
}>();

const hover = ref(false);
const draghover = ref(false);
const isDragging = ref(false);

const title = computed(() => props.folder.name);

function checkboxClicked() {
	emit('chosen', props.folder);
}

function onClick() {
	emit('move', props.folder);
}

function onMouseover() {
	hover.value = true;
}

function onMouseout() {
	hover.value = false;
}

function onDragover(ev: DragEvent) {
	if (!ev.dataTransfer) return;

	// 自分自身がドラッグされている場合
	if (isDragging.value) {
		// 自分自身にはドロップさせない
		ev.dataTransfer.dropEffect = 'none';
		return;
	}

	const isFile = ev.dataTransfer.items[0].kind === 'file';
	const isDriveFile = ev.dataTransfer.types[0] === _DATA_TRANSFER_DRIVE_FILE_;
	const isDriveFolder = ev.dataTransfer.types[0] === _DATA_TRANSFER_DRIVE_FOLDER_;

	if (isFile || isDriveFile || isDriveFolder) {
		switch (ev.dataTransfer.effectAllowed) {
			case 'all':
			case 'uninitialized':
			case 'copy':
			case 'copyLink':
			case 'copyMove':
				ev.dataTransfer.dropEffect = 'copy';
				break;
			case 'linkMove':
			case 'move':
				ev.dataTransfer.dropEffect = 'move';
				break;
			default:
				ev.dataTransfer.dropEffect = 'none';
				break;
		}
	} else {
		ev.dataTransfer.dropEffect = 'none';
	}
}

function onDragenter() {
	if (!isDragging.value) draghover.value = true;
}

function onDragleave() {
	draghover.value = false;
}

function onDrop(ev: DragEvent) {
	draghover.value = false;

	if (!ev.dataTransfer) return;

	// ファイルだったら
	if (ev.dataTransfer.files.length > 0) {
		for (const file of Array.from(ev.dataTransfer.files)) {
			emit('upload', file, props.folder);
		}
		return;
	}

	//#region ドライブのファイル
	const driveFile = ev.dataTransfer.getData(_DATA_TRANSFER_DRIVE_FILE_);
	if (driveFile != null && driveFile !== '') {
		const file = JSON.parse(driveFile);
		emit('removeFile', file.id);
		os.api('drive/files/update', {
			fileId: file.id,
			folderId: props.folder.id,
		});
	}
	//#endregion

	//#region ドライブのフォルダ
	const driveFolder = ev.dataTransfer.getData(_DATA_TRANSFER_DRIVE_FOLDER_);
	if (driveFolder != null && driveFolder !== '') {
		const folder = JSON.parse(driveFolder);

		// 移動先が自分自身ならreject
		if (folder.id === props.folder.id) return;

		emit('removeFolder', folder.id);
		os.api('drive/folders/update', {
			folderId: folder.id,
			parentId: props.folder.id,
		}).then(() => {
			// noop
		}).catch(err => {
			switch (err.code) {
				case 'RECURSIVE_NESTING':
					claimAchievement('driveFolderCircularReference');
					os.alert({
						type: 'error',
						title: i18n.ts.unableToProcess,
						text: i18n.ts.circularReferenceFolder,
					});
					break;
				default:
					os.alert({
						type: 'error',
						text: i18n.ts.somethingHappened,
					});
			}
		});
	}
	//#endregion
}

function onDragstart(ev: DragEvent) {
	if (!ev.dataTransfer) return;

	ev.dataTransfer.effectAllowed = 'move';
	ev.dataTransfer.setData(_DATA_TRANSFER_DRIVE_FOLDER_, JSON.stringify(props.folder));
	isDragging.value = true;

	// 親ブラウザに対して、ドラッグが開始されたフラグを立てる
	// (=あなたの子供が、ドラッグを開始しましたよ)
	emit('dragstart');
}

function onDragend() {
	isDragging.value = false;
	emit('dragend');
}

function go() {
	emit('move', props.folder.id);
}

function rename() {
	os.inputText({
		title: i18n.ts.renameFolder,
		placeholder: i18n.ts.inputNewFolderName,
		default: props.folder.name,
	}).then(({ canceled, result: name }) => {
		if (canceled) return;
		os.api('drive/folders/update', {
			folderId: props.folder.id,
			name: name,
		});
	});
}

function deleteFolder() {
	os.api('drive/folders/delete', {
		folderId: props.folder.id,
	}).then(() => {
		if (defaultStore.state.uploadFolder === props.folder.id) {
			defaultStore.set('uploadFolder', null);
		}
	}).catch(err => {
		switch (err.id) {
			case 'b0fc8a17-963c-405d-bfbc-859a487295e1':
				os.alert({
					type: 'error',
					title: i18n.ts.unableToDelete,
					text: i18n.ts.hasChildFilesOrFolders,
				});
				break;
			default:
				os.alert({
					type: 'error',
					text: i18n.ts.unableToDelete,
				});
		}
	});
}

function setAsUploadFolder() {
	defaultStore.set('uploadFolder', props.folder.id);
}

function onContextmenu(ev: MouseEvent) {
	let menu;
	menu = [{
		text: i18n.ts.openInWindow,
		icon: 'ti ti-app-window',
		action: () => {
			os.popup(defineAsyncComponent(() => import('@/components/MkDriveWindow.vue')), {
				initialFolder: props.folder,
			}, {
			}, 'closed');
		},
	}, null, {
		text: i18n.ts.rename,
		icon: 'ti ti-forms',
		action: rename,
	}, null, {
		text: i18n.ts.delete,
		icon: 'ti ti-trash',
		danger: true,
		action: deleteFolder,
	}];
	if (defaultStore.state.devMode) {
		menu = menu.concat([null, {
			icon: 'ti ti-id',
			text: i18n.ts.copyFolderId,
			action: () => {
				copyToClipboard(props.folder.id);
			},
		}]);
	}
	os.contextMenu(menu, ev);
}
</script>

<style lang="scss" module>
.root {
	position: relative;
	padding: 8px;
	height: 64px;
	background: var(--driveFolderBg);
	border-radius: 4px;
	cursor: pointer;

	&.draghover {
		&:after {
			content: "";
			pointer-events: none;
			position: absolute;
			top: -4px;
			right: -4px;
			bottom: -4px;
			left: -4px;
			border: 2px dashed var(--focus);
			border-radius: 4px;
		}
	}
}

.checkbox {
	position: absolute;
	bottom: 8px;
	right: 8px;
	width: 16px;
	height: 16px;
	background: #fff;
	border: solid 1px #000;

	&.checked {
		background: var(--accent);
	}
}

.name {
	margin: 0;
	font-size: 0.9em;
	color: var(--desktopDriveFolderFg);
}

.icon {
	margin-right: 4px;
	margin-left: 2px;
	text-align: left;
}

.upload {
	margin: 4px 4px;
	font-size: 0.8em;
	text-align: right;
	color: var(--desktopDriveFolderFg);
}
</style>
