use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "35972",
    description => "Add course_type column to courses table for flexible course displays",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'courses', 'course_type' ) ) {
            say_info( $out, "Adding course_type column to courses table..." );

            # Add the course_type column with default value 'COURSE'
            $dbh->do(
                q{
                ALTER TABLE courses
                ADD COLUMN course_type VARCHAR(80) DEFAULT 'COURSE'
                AFTER course_id
            }
            );

            say_success( $out, "Added column 'courses.course_type'" );

            # Migrate existing 'thesis tables' (department='TT') to new system
            my $migrated_courses = $dbh->do(
                q{
                UPDATE courses
                SET course_type = 'RESEARCH_TABLE'
                WHERE department = 'TT'
            }
            );

            if ( $migrated_courses && $migrated_courses > 0 ) {
                say_success( $out, "Migrated $migrated_courses thesis table(s) to course_type='RESEARCH_TABLE'" );
            } else {
                say_info( $out, "No thesis tables (department='TT') found to migrate" );
            }

            # Add authorized value category for course types
            $dbh->do(
                q{
                INSERT IGNORE INTO authorised_value_categories (category_name, is_system)
                VALUES ('CR_TYPE', 1)
            }
            );
            say_success( $out, "Added authorized value category 'CR_TYPE'" );

            # Add default authorized values for course types
            $dbh->do(
                q{
                INSERT IGNORE INTO authorised_values (category, authorised_value, lib, lib_opac)
                VALUES
                    ('CR_TYPE', 'COURSE', 'Course reserve', 'Course reserve'),
                    ('CR_TYPE', 'RESEARCH_TABLE', 'Research table', 'Research table'),
                    ('CR_TYPE', 'ON_DISPLAY', 'On display', 'On display')
            }
            );
            say_success( $out, "Added default course type authorized values" );

            say_info( $out, "Course types can be customized in Administration > Authorized values > CR_TYPE" );
            say_info( $out, "The 'lib' field controls staff interface display text" );
            say_info( $out, "The 'lib_opac' field controls OPAC display text" );
            say_success( $out, "Migration complete: Course reserves now supports multiple display types" );

        } else {
            say_info( $out, "The course_type column already exists in the courses table." );
        }
    },
};
