
CREATE TABLE IF NOT EXISTS `notices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `title` varchar(50) NOT NULL,
  `description` text NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

