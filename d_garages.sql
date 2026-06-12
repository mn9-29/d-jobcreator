-- ════════════════════════════════════════════════════════════════
--  d-jobcreator installation (ESX / QBCore / QBX)
--  Safe to run on any framework. Uses MariaDB "IF NOT EXISTS" syntax.
-- ════════════════════════════════════════════════════════════════

-- Jobs table (already present on ESX; created here for QBCore/QBX).
CREATE TABLE IF NOT EXISTS `jobs` (
  `name` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `whitelisted` tinyint(1) NOT NULL DEFAULT 0,
  `stash_location` text DEFAULT NULL,
  `stash_capacity` int(11) DEFAULT 0,
  `stash_slots` int(11) DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `job_grades` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_name` varchar(50) NOT NULL,
  `grade` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `label` varchar(100) NOT NULL,
  `salary` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_grade` (`job_name`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stash columns for servers where the jobs table already existed (ESX).
ALTER TABLE `jobs` ADD COLUMN IF NOT EXISTS `stash_location` TEXT DEFAULT NULL;
ALTER TABLE `jobs` ADD COLUMN IF NOT EXISTS `stash_capacity` INT(11) DEFAULT 0;
ALTER TABLE `jobs` ADD COLUMN IF NOT EXISTS `stash_slots` INT(11) DEFAULT 0;

-- Garages.
CREATE TABLE IF NOT EXISTS `d_garages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `location` varchar(100) NOT NULL,
  `spawn_location` varchar(100) NOT NULL,
  `vehicles` text NOT NULL,
  `type` enum('car','helicopter','boat') NOT NULL,
  `blip` tinyint(1) NOT NULL DEFAULT 1,
  `job` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
