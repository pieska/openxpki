use strict;
use warnings;
use English;
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use FindBin qw( $Bin );

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

#
# setup
#
require "$Bin/DatabaseTest.pm";

my $db = DatabaseTest->new(
    columns => [ # yes an ArrayRef to have a defined order!
        id => "INTEGER PRIMARY KEY",
        text => "VARCHAR(100)",
        entropy => "INTEGER",
    ],
    data => [
        [ 1, "Litfasssaeule", 1 ],
        [ 2, "Buergersteig",  1 ],
        [ 3, "Rathaus",       42 ],
        [ 4, "Kindergarten",  3 ],
        [ 5, "Luft",          undef ],
    ],
);

#
# tests
#
$db->run("SQL DELETE", 14, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    # no delete with non-matching where clause
    lives_and {
        $rownum = $dbi->delete(
            from => "test",
            where => { entropy => 99 },
        );
        ok $rownum == 0;
    } "no deletion with non-matching where clause";

    cmp_bag $t->get_data, [
        [ 1, "Litfasssaeule", 1 ],
        [ 2, "Buergersteig",  1 ],
        [ 3, "Rathaus",       42 ],
        [ 4, "Kindergarten",  3 ],
        [ 5, "Luft",          undef ],
    ], "all rows are still there";

    # delete one existing row
    lives_and {
        $rownum = $dbi->delete(
            from => "test",
            where => [ -and => { text => "Rathaus" }, { entropy => 42 } ],
        );
        is $rownum, 1;
    } "delete one row";

    cmp_bag $t->get_data, [
        [ 1, "Litfasssaeule", 1],
        [ 2, "Buergersteig",  1],
        [ 4, "Kindergarten",  3],
        [ 5, "Luft",          undef ],
    ], "deleted rows are really gone";

    # delete two existing rows
    lives_and {
        $rownum = $dbi->delete(
            from => "test",
            where => { entropy => 1 },
        );
        is $rownum, 2;
    } "delete multiple rows";

    cmp_bag $t->get_data, [
        [ 4, "Kindergarten",  3],
        [ 5, "Luft",          undef ],
    ], "deleted rows are really gone";

    # delete using literal WHERE clause
    lives_and {
        $rownum = $dbi->delete(
            from => "test",
            where => \"entropy IS NULL",
        );
        is $rownum, 1;
    } "delete using literal WHERE clause";

    cmp_bag $t->get_data, [
        [ 4, "Kindergarten",  3],
    ], "deleted rows are really gone";

    # prevent accidential deletion of all rows
    dies_ok {
        $dbi->delete(from => "test")
    } "prevent accidential deletion of all rows (no WHERE clause)";

    dies_ok {
        $dbi->delete(from => "test", where => "")
    } "prevent accidential deletion of all rows (empty WHERE string)";

    dies_ok {
        $dbi->delete(from => "test", where => {})
    } "prevent accidential deletion of all rows (empty WHERE hash)";

    dies_ok {
        $dbi->delete(from => "test", where => [])
    } "prevent accidential deletion of all rows (empty WHERE array)";

    lives_ok {
        $dbi->delete(from => "test", all => 1)
    } "allow intended deletion of all rows";

    cmp_bag $t->get_data, [];
});

done_testing($db->test_no);
