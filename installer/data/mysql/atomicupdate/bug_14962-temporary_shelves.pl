use Modern::Perl;

return {
    bug_number  => "14962",
    description => "Add display tables for display module",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Create displays table
        unless ( TableExists('displays') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `displays` (
                    `display_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique id for the display',
                    `display_name` varchar(255) DEFAULT NULL COMMENT 'the name of the display',
                    `start_date` date DEFAULT NULL COMMENT 'the start date of the display (optional)',
                    `end_date` date DEFAULT NULL COMMENT 'the end date of the display (optional)',
                    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'determines whether the display is active',
                    `display_location` varchar(80) DEFAULT NULL COMMENT 'the shelving location for the display (optional)',
                    `display_code` varchar(80) DEFAULT NULL COMMENT 'the collection code for the display (optional)',
                    `display_branch` varchar(10) DEFAULT NULL COMMENT 'the branch code for the display (optional)',
                    `display_home_branch` varchar(10) DEFAULT NULL COMMENT 'a new home branch for the item to have while on display (optional)',
                    `display_holding_branch` varchar(10) DEFAULT NULL COMMENT 'a new holding branch for the item to have while on display (optional)',
                    `display_itype` varchar(10) DEFAULT NULL COMMENT 'a new itype for the item to have while on display (optional)',
                    `staff_note` mediumtext DEFAULT NULL COMMENT 'staff note for the display',
                    `public_note` mediumtext DEFAULT NULL COMMENT 'public note for the display',
                    `display_days` int(11) DEFAULT NULL COMMENT 'default number of days items will remain on display',
                    `display_return_over` enum('any','any_except_homebranch','no') NOT NULL DEFAULT 'no' COMMENT 'should the item be removed from the display when it is returned',
                    PRIMARY KEY (`display_id`),
                    KEY `display_branch` (`display_branch`),
                    KEY `display_holding_branch` (`display_holding_branch`),
                    KEY `display_itype` (`display_itype`),
                    CONSTRAINT `displays_ibfk_1` FOREIGN KEY (`display_branch`) REFERENCES `branches` (`branchcode`) ON DELETE SET NULL ON UPDATE CASCADE,
                    CONSTRAINT `displays_ibfk_2` FOREIGN KEY (`display_home_branch`) REFERENCES `branches` (`branchcode`) ON DELETE SET NULL ON UPDATE CASCADE,
                    CONSTRAINT `displays_ibfk_3` FOREIGN KEY (`display_holding_branch`) REFERENCES `branches` (`branchcode`) ON DELETE SET NULL ON UPDATE CASCADE,
                    CONSTRAINT `displays_ibfk_4` FOREIGN KEY (`display_itype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE SET NULL ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );

            say $out "Added new table 'displays'";
        }

        # Create display_items table
        unless ( TableExists('display_items') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `display_items` (
                    `display_item_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `display_id` int(11) NOT NULL COMMENT 'foreign key to link to displays.display_id',
                    `itemnumber` int(11) DEFAULT NULL COMMENT 'items.itemnumber for the item on display',
                    `biblionumber` int(11) DEFAULT NULL COMMENT 'biblio.biblionumber for the bibliographic record on display',
                    `date_added` date DEFAULT NULL COMMENT 'the date the item was added to the display',
                    `date_remove` date DEFAULT NULL COMMENT 'the date the item should be removed from the display',
                    PRIMARY KEY (`display_item_id`),
                    UNIQUE KEY `display_items_uniq` (`display_id`,`itemnumber`),
                    KEY `display_id` (`display_id`),
                    KEY `itemnumber` (`itemnumber`),
                    KEY `biblionumber` (`biblionumber`),
                    CONSTRAINT `display_items_ibfk_1` FOREIGN KEY (`display_id`) REFERENCES `displays` (`display_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `display_items_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `display_items_ibfk_3` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );

            say $out "Added new table 'display_items'";
        }

        # Add UseDisplayModule system preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES ('UseDisplayModule', '0', NULL, 'Enable the display module for managing item displays.', 'YesNo')
        }
        );
        say $out "Added UseDisplayModule system preference";

        # Add displays user flag
        $dbh->do(
            q{
            INSERT IGNORE INTO userflags (bit, flag, flagdesc, defaulton) VALUES
                (33, 'displays', 'Display module', 0)
        }
        );
        say $out "Added displays user flag";

        # Add display permissions
        $dbh->do(
            q{
            INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
                (33, 'add_displays', 'Create displays'),
                (33, 'add_displays_to_any_libraries', 'Create displays in any libraries'),
                (33, 'view_displays', 'View displays'),
                (33, 'view_displays_from_any_libraries', 'View displays from any libraries'),
                (33, 'edit_displays', 'Edit displays'),
                (33, 'edit_displays_from_any_libraries', 'Edit displays from any libraries'),
                (33, 'delete_displays', 'Delete displays'),
                (33, 'delete_displays_from_any_libraries', 'Delete displays from any libraries'),
                (33, 'manage_display_items', 'Create, view, edit, and delete display items')
        }
        );
        say $out "Added display permissions";

        # Add AV category and entries for displays
        $dbh->do(
            q{
            INSERT IGNORE INTO authorised_value_categories( category_name, is_system ) VALUES ('DISPLAY_RETURN_OVER', 1);
        }
        );
        say $out "Added DISPLAY_RETURN_OVER authorised_value_category";

        $dbh->do(
            q{
            INSERT IGNORE INTO authorised_values (category, authorised_value, lib)
            VALUES
                ('DISPLAY_RETURN_OVER', 'any', 'Remove from display when checked-in at any library'),
                ('DISPLAY_RETURN_OVER', 'any_except_homebranch', 'Remove from display when checked-in at any library, except permenant home library'),
                ('DISPLAY_RETURN_OVER', 'no', 'Do nothing')
        }
        );
        say $out "Added default authorised values for DISPLAY_RETURN_OVER";

        # Add ft_display_group column to library_groups table
        unless ( column_exists( 'library_groups', 'ft_display_group' ) ) {
            $dbh->do(
                q{
                ALTER TABLE library_groups
                ADD COLUMN `ft_display_group` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Use this group to identify libraries that can share display items' AFTER `ft_local_float_group`
            }
            );
            say $out "Added ft_display_group column to library_groups table";
        }
    },
};
