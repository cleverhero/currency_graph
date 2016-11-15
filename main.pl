use GD::Graph;
use strict;
use CGI ':standard';
use v5.10.12;
use HTML::TableExtract;
use GD::Graph::lines;
use WWW::Mechanize;
use Date;

my %data;

my($webID, $d1, $d2) = @ARGV;
my $date1 = Date->new ($d1);
my $date2 = Date->new ($d2);

my %websites = (
    cb => 'http://www.cbr.ru',
    val => 'http://val.ru',
    fm => 'http://www.finmarket.ru' 
);

my %unitPrice = (
    'USD' => 1,
    'EUR' => 1,
    'CNY' => 10,
    'JPY' => 100);

my %currencyKeys = (
    cb => {
        'R01235' => 'USD',
        'R01239' => 'EUR',
        'R01375' => 'CNY',
        'R01820' => 'JPY'
        },
    val => {
        '840' => 'USD',
        '978' => 'EUR',
        '156' => 'CNY',
        '392' => 'JPY'
        },
    fm => {
        '52148' => 'USD',
        '52170' => 'EUR',
        '52207' => 'CNY',
        '52246' => 'JPY'
        }
);
die "Wrong time interval" unless ($date2 - $date1 >= 0);  
die "Wrong website Id" unless exists($currencyKeys{$webID});  

sub createPng {
    my $image = shift;
    my $fname = shift;
    
    open    (my $file, ">$fname.png") or die $!;
    binmode ($file);
    print    $file $image->png;
    close   ($file);
    
    return 1;
}

sub currencyTable {
    my ($link, %atr) = @_;
    say $link;
    my $mech = WWW::Mechanize->new();
    $mech->get($link);
    my $table = HTML::TableExtract->new(%atr);
    return $table->parse($mech->content());
}

sub getUrl {
    my $cur = shift;
    
    my @d1P = $date1->getDatePatrs;
    my @d2P = $date2->getDatePatrs;
 
    given ($webID) {
        return "http://www.cbr.ru/currency_base/dynamics.aspx?VAL_NM_RQ=$cur&date_req1=$date1&date_req2=$date2&rt=1&mode=1" 
             when 'cb';
        return "http://val.ru/valhistory.asp?tool=$cur&bd=$d1P[0]&bm=$d1P[1]&by=$d1P[2]&ed=$d2P[0]&em=$d2P[1]&ey=$d2P[2]&showchartp=False" 
             when 'val';
        return "http://www.finmarket.ru/currency/rates/?id=10148&pv=1&cur=$cur&bd=$d1P[0]&bm=$d1P[1]&by=$d1P[2]&ed=$d2P[0]&em=$d2P[1]&ey=$d2P[2]&x=36&y=16#archive"
             when 'fm';
    }
}

sub getSearchAttributes {
    given ($webID) {
        return  (attribs => {class => 'data'})
            when 'cb';
        return   (attribs =>{border => 0, 
                                     width => 433, 
                                     cellpadding => 6, 
                                     cellspacing => 1 
                                           })
            when 'val';
        return (attribs => {class => 'karramba'}) 
            when 'fm';
    }
}

foreach my $key (keys %{$currencyKeys{$webID}}) {
    my $table = currencyTable(getUrl($key),getSearchAttributes);
    foreach my $ts ( $table->tables ) {
        my @rows = $ts->rows;
        for my $i(1..$#rows) {    
            $data{date}[$i - 1] = $rows[$i][0];
            $data{$currencyKeys{$webID}{$key}}[$i - 1] = ($rows[$i][2]/$rows[$i][1]) * $unitPrice{$currencyKeys{$webID}{$key}};
       }
    }
}

my @graphData = (\@{$data{date}});
foreach my $key (keys %{$currencyKeys{$webID}}) {
    push(@graphData,\@{$data{$currencyKeys{$webID}{$key}}});
}

my $skip = int((($date2 - $date1) * 8)/(1000-70) + 1);
my @colors = ['green', 'blue', 'red', 'black'];
my %config = (
    title           => 'Time interval of currency change',
    x_label         => 'Date',
    y_label         => 'Currency',
 
    dclrs           => @colors,  
    bgclr         => 'white',   # background colour
    fgclr         => 'black',   # Axes and grid
    boxclr        => undef,     # Fill colour for box axes, default: not used
    accentclr     => 'black',    # bar, area and pie outlines.
    labelclr      => 'black',   # labels on axes
    axislabelclr  => 'black',   # values on axes
    legendclr     => 'black',   # Text for the legend
    textclr       => 'black',   # All text, apart from the following 2
    
    x_label_skip    =>  $skip,
    x_tick_offset     => ($date2 - $date1) % $skip,
    x_labels_vertical => 1,
    transparent => 0,
 
    y_tick_number   =>  8,
);
 
my $lineGraph = GD::Graph::lines->new(1000, 700);
$lineGraph->set(%config) or warn $lineGraph->error;
$lineGraph->set_legend_font('GD::gdMediumNormalFont');
my @titles;
foreach my $key (keys  %{$currencyKeys{$webID}}) {
    push(@titles,$currencyKeys{$webID}{$key} . " ($unitPrice{$currencyKeys{$webID}{$key}})");
}
$lineGraph->set_legend(@titles);
my $lineImage = $lineGraph->plot(\@graphData) or die $lineGraph->error;

createPng($lineImage, 'lineGraph');