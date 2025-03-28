/*
 * SPDX-FileCopyrightText: syuilo and other misskey contributors
 * SPDX-License-Identifier: AGPL-3.0-only
 */

import { PrimaryColumn, Entity, Index, JoinColumn, Column, ManyToOne } from 'typeorm';
import { id } from '../id.js';
import { MiUser } from './User.js';
import { MiUserList } from './UserList.js';

@Entity('user_list_favorite')
@Index(['userId', 'userListId'], { unique: true })
export class MiUserListFavorite {
	@PrimaryColumn(id())
	public id: string;

	@Column('timestamp with time zone')
	public createdAt: Date;

	@Index()
	@Column(id())
	public userId: MiUser['id'];

	@ManyToOne(type => MiUser, {
		onDelete: 'CASCADE',
	})
	@JoinColumn()
	public user: MiUser | null;

	@Column(id())
	public userListId: MiUserList['id'];

	@ManyToOne(type => MiUserList, {
		onDelete: 'CASCADE',
	})
	@JoinColumn()
	public userList: MiUserList | null;
}
