CREATE TABLE `app_refs` (
	`user_id` text NOT NULL,
	`app_ref` text NOT NULL,
	`tag` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `app_ref`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `blocks_meta` (
	`user_id` text NOT NULL,
	`block_ref` text NOT NULL,
	`schedule` text NOT NULL,
	`app_refs` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `block_ref`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `events` (
	`event_id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`device_id` text NOT NULL,
	`type` text NOT NULL,
	`app_ref` text,
	`block_ref` text,
	`occurred_at` integer NOT NULL,
	`tz_offset` integer NOT NULL,
	`received_at` integer NOT NULL,
	`wait_minutes` integer,
	`free` integer,
	`session_minutes` integer,
	`payload` text,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `events_user_time` ON `events` (`user_id`,`occurred_at`);--> statement-breakpoint
CREATE INDEX `events_received` ON `events` (`received_at`);--> statement-breakpoint
CREATE TABLE `exam_weeks` (
	`user_id` text NOT NULL,
	`week` text NOT NULL,
	PRIMARY KEY(`user_id`, `week`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `hour_histograms` (
	`user_id` text NOT NULL,
	`week` text NOT NULL,
	`hours` text NOT NULL,
	PRIMARY KEY(`user_id`, `week`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `rollups_daily` (
	`user_id` text NOT NULL,
	`day` text NOT NULL,
	`passes` integer DEFAULT 0 NOT NULL,
	`free` integer DEFAULT 0 NOT NULL,
	`waited` integer DEFAULT 0 NOT NULL,
	`hits` integer DEFAULT 0 NOT NULL,
	`held` integer DEFAULT 0 NOT NULL,
	`abandoned` integer DEFAULT 0 NOT NULL,
	`wait_minutes` integer DEFAULT 0 NOT NULL,
	`active` integer DEFAULT false NOT NULL,
	`level` integer,
	PRIMARY KEY(`user_id`, `day`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `rollups_weekly` (
	`user_id` text NOT NULL,
	`week` text NOT NULL,
	`passes` integer DEFAULT 0 NOT NULL,
	`free` integer DEFAULT 0 NOT NULL,
	`waited` integer DEFAULT 0 NOT NULL,
	`hits` integer DEFAULT 0 NOT NULL,
	`held` integer DEFAULT 0 NOT NULL,
	`abandoned` integer DEFAULT 0 NOT NULL,
	`wait_minutes` integer DEFAULT 0 NOT NULL,
	`clean_days` integer DEFAULT 0 NOT NULL,
	`active_days` integer DEFAULT 0 NOT NULL,
	`trend` real,
	PRIMARY KEY(`user_id`, `week`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `rollups_weekly_week` ON `rollups_weekly` (`week`);--> statement-breakpoint
CREATE TABLE `auth_identities` (
	`subject_hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`provider` text NOT NULL,
	`apple_refresh_token_enc` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `auth_identities_user` ON `auth_identities` (`user_id`);--> statement-breakpoint
CREATE TABLE `devices` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`push_token` text,
	`push_environment` text,
	`timezone` text,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `devices_user` ON `devices` (`user_id`);--> statement-breakpoint
CREATE TABLE `email_codes` (
	`key` text PRIMARY KEY NOT NULL,
	`code_hash` text NOT NULL,
	`expires_at` integer NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`locked_until` integer,
	`sent_at` integer NOT NULL,
	`school_id` integer
);
--> statement-breakpoint
CREATE TABLE `idempotency_keys` (
	`user_id` text NOT NULL,
	`key` text NOT NULL,
	`status` integer NOT NULL,
	`body` text NOT NULL,
	`created_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `key`)
);
--> statement-breakpoint
CREATE TABLE `sessions` (
	`token_hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`device_id` text,
	`created_at` integer NOT NULL,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `sessions_user` ON `sessions` (`user_id`);--> statement-breakpoint
CREATE TABLE `tombstones` (
	`subject_hash` text PRIMARY KEY NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`display_name` text,
	`handle` text,
	`photo_key` text,
	`handle_changed_at` integer,
	`email` text,
	`discoverable` integer DEFAULT true NOT NULL,
	`timezone` text DEFAULT 'UTC' NOT NULL,
	`notify_enabled` integer DEFAULT true NOT NULL,
	`notify_hour` integer,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_handle_unique` ON `users` (`handle`);--> statement-breakpoint
CREATE TABLE `school_domains` (
	`domain` text PRIMARY KEY NOT NULL,
	`school_id` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `school_domains_school` ON `school_domains` (`school_id`);--> statement-breakpoint
CREATE TABLE `school_memberships` (
	`user_id` text PRIMARY KEY NOT NULL,
	`school_id` integer NOT NULL,
	`email_hash` text NOT NULL,
	`verified_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `school_memberships_school` ON `school_memberships` (`school_id`);--> statement-breakpoint
CREATE TABLE `school_rollups_weekly` (
	`school_id` integer NOT NULL,
	`week` text NOT NULL,
	`active_members` integer NOT NULL,
	`hits` integer NOT NULL,
	`held` integer NOT NULL,
	`passes_median` real NOT NULL,
	`passes_histogram` text NOT NULL,
	`by_hour` text NOT NULL,
	`tag_share` text NOT NULL,
	`exam_marks` integer NOT NULL,
	`computed_at` integer NOT NULL,
	PRIMARY KEY(`school_id`, `week`)
);
--> statement-breakpoint
CREATE TABLE `schools` (
	`id` integer PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`country` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `contact_hashes` (
	`user_id` text NOT NULL,
	`hash` text NOT NULL,
	PRIMARY KEY(`user_id`, `hash`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `contact_hashes_hash` ON `contact_hashes` (`hash`);--> statement-breakpoint
CREATE TABLE `friendships` (
	`user_lo` text NOT NULL,
	`user_hi` text NOT NULL,
	`status` text NOT NULL,
	`requested_by` text NOT NULL,
	`created_at` integer NOT NULL,
	`accepted_at` integer,
	PRIMARY KEY(`user_lo`, `user_hi`),
	FOREIGN KEY (`user_lo`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`user_hi`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `friendships_hi` ON `friendships` (`user_hi`);--> statement-breakpoint
CREATE TABLE `invites` (
	`code` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `invites_user` ON `invites` (`user_id`);--> statement-breakpoint
CREATE TABLE `person_blocks` (
	`blocker_id` text NOT NULL,
	`blocked_id` text NOT NULL,
	`created_at` integer NOT NULL,
	PRIMARY KEY(`blocker_id`, `blocked_id`),
	FOREIGN KEY (`blocker_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`blocked_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `person_blocks_blocked` ON `person_blocks` (`blocked_id`);--> statement-breakpoint
CREATE TABLE `reports` (
	`id` text PRIMARY KEY NOT NULL,
	`reporter_id` text NOT NULL,
	`subject_id` text NOT NULL,
	`reason` text NOT NULL,
	`text` text,
	`created_at` integer NOT NULL
);
