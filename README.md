# ernie
Eclectic Reporting system using Perl and JS based off Java Birt conceptually

This is a banded report generator written in a mixture of Perl, HTML, and JS. Conceptually it is loosely based off of the way Java "Birt" reporting works, but is many times faster and much more ecletic.

Rather than rely upon many layers of Java components and a hugely complex codebase, this project aims to use a minimal amount of code to replicate the functionality that Birt provides, but in a clean simple fashion.

This project uses the following other projects to accomplish this:
* CPAN XML parser XML::Bare to read in main configuration
* Perl module Template::Bare for templates within XML ( based off CPAN Text::Template )
* Perl module PSQL::Helper for ease in extracting data from Postgres
* CPAN JSON module JSON::XS for shifting data from the "backend" to the "frontend"
* Protocut JS library for basic classes and DOM manipulation
* Chartist JS library for rendering bar and pie charts
* PageSpanner JS library for creating banded reports/tables from JSON data
* wkhtmltopdf system for rendering HTML report into PDF ( phantomjs was tried also, but it was slower )

It provides the following benefits over Java Birt:
* It is much faster ( 5-7x )
* No wonky GUI system is needed to create reports ( just flat XML text files )
* It can easily be customized:
  * To use whatever extra Perl code you want
  * To use whatever JS charting library you want
* It has built in support for creating a Table of Contents with page numbers within the created PDF
* It uses a lot less memory to run
* The entire codebase is nearly 100x smaller than Java Birt, so it is easy to modify as needed
  to suit custom purposes.
* Generated PDFs have the following features:
  * They can easily use custom fonts
  * The built in bookmarks of PDF are supported well, with a tree
* Due to using HTML/JS for rendering, the following are true:
  * All elements support CSS for high quality layout
  * Tables don't have wonky border edges like they do in Birt generated reports
  * Anything that can be added to normal HTML webpages can be added to reports

Running a report requires the following steps to occur in the system:
1. Data is pulled from a database and stored in an XML file.
   Current example has data being pulled from Postgres views.
1. Configuration is processed to generate table and chart data from the raw xml data
1. Templates are parsed against the result of table and chart generation to pass to rendering
1. Rendering is done, combining template information with table and chart data to render a combined paged report
