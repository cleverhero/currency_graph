use GD::Graph;
use strict;
#use warnings;
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
    
    my ($d1,$m1,$y1) = $date1->getDateParts;
    my ($d2,$m2,$y2) = $date2->getDateParts;
 
    given ($webID) {
        return "http://www.cbr.ru/currency_base/dynamics.aspx?VAL_NM_RQ=$cur&date_req1=$date1&date_req2=$date2&rt=1&mode=1" 
             when 'cb';
        return "http://val.ru/valhistory.asp?tool=$cur&bd=$d1&bm=$m1&by=$y1&ed=$d2&em=$m2&ey=$y2&showchartp=False" 
             when 'val';
        return "http://www.finmarket.ru/currency/rates/?id=10148&pv=1&cur=$cur&bd=$d1&bm=$m1&by=$y1&ed=$d2&em=$m2&ey=$y2&x=36&y=16#archive"
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
    foreach my $ts ($table->tables) {
        my (undef, @rows) = $ts->rows;
        foreach my $cell(@rows) {          
            if ($#{$data{date}} < $#rows) {                push(@{$data{date}},$cell->[0]);
            }               push(@{$data{$currencyKeys{$webID}{$key}}}, (($cell->[2]/$cell->[1]) * $unitPrice{$currencyKeys{$webID}{$key}}));
       }
    }
}

my @graphData = $data{date};
@graphData = @data{keys %data};
my ($gWidth,$gHeight) = (1000,700);
my $skip = int((($date2 - $date1) * 8)/($gWidth-$gHeight/10) + 1);
my @colors = ['green', 'blue', 'red', 'black'];
my %config = (
    title           => 'Time interval of currency change',
    x_label         => 'Date',
    y_label         => 'Currency',
 
    dclrs         => @colors,  
    bgclr         => 'white',   # background colour
    fgclr         => 'black',   # Axes and grid
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
 
my $lineGraph = GD::Graph::lines->new($gWidth, $gHeight);
$lineGraph->set(%config) or warn $lineGraph->error;
$lineGraph->set_legend_font('GD::gdMediumNormalFont');

my @titles = map {$currencyKeys{$webID}{$_}} keys %{$currencyKeys{$webID}};

$lineGraph->set_legend(reverse(@titles));
my $lineImage = $lineGraph->plot(\@graphData) or die $lineGraph->error;

createPng($lineImage, 'lineGraph');