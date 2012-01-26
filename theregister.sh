#!/usr/bin/env bash

# The Register newsreader script
# Copyright (C) April 2010 by Oliver Jones
# BSD licence - feel free to use or modify, with original attribution.
#
# https://www.sunwcall.com/forum/showthread.php?t=22


# Fetch front news page
RSFNP=`curl -s www.theregister.co.uk | tr -cd '\11\12\40-\176'`

# Spit it out...
RSIDX=`echo "$RSFNP" |

        # Register headlines are printed in <h3> with a date at the beginning of the article URL
        egrep -i '^<h3><a href="/[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9].*' | \

        # Strip out the actual story title from between the HTML <a href=...> tag and its </a> twin
        sed -n 's/<h3><a href="[^"]*">\([^<]*\)<\/a><\/h3>/\1/p' | \

        # Sort in dictionary order (and ignore case)
        sort -df | \

        # Finally, number each line with a tab separating the number from the title
        sed -e '/./=' | sed -e '/./N; s/\n/\t/'`

# If we don't get a sane terminal width, we will assume 80 columns
if [ -z "${COLUMNS}" ] ; then
COLUMNS=80
fi

# We take just one argument (which is optional) - the article number
SEL=$1

# If the argument is not supplied, we substitute the null value for one which won't match any headline numbers
if [ -z "${SEL}" ] ; then
SEL="NULL"
fi

# Now we look to see if the headline number matches any we have available. If one matches, we extract the headline title.
RSHDL=`echo "$RSIDX" | grep $SEL | head -n 1 | sed -n 's/^[0-9]*\t\(.*\)/\1/p'`
# We can figure out if we actually struck gold by counting the number of URLs matched...
MATCH=`echo "$RSIDX" | grep $SEL | sed -n 's/^[0-9]*\t\(.*\)/\1/p' | wc -l`

# If we actually have a match, then we proceed to build the URL of the article we need to fetch
if [ ${MATCH} -gt 0 ] ; then

        # 1st part of the URL is easy - it will be "www.theregister.co.uk"
        RSURL1="www.theregister.co.uk"

        # 2nd part of the URL will be the relative URL extracted from the HTML
        RSURL2=`echo "$RSFNP" | grep "$RSHDL" | sed -n 's/^<h3><a href="\([^"]*\)".*/\1/p'`

        # Join them together...
        RSURL="${RSURL1}${RSURL2}"

        # For now, we assume there are more pages to come, but the first page is never explicitly targeted
        RSNPG="TRUE"
        RSPEX=""
        RSPGN="1"

        # An article may consist of several pages...
        while [ $RSNPG = "TRUE" ] ; do

                # Fetch the article...
                RSTMP=`curl -s ${RSURL}${RSPEX}`

                # Look for the link to the next page of the story, if there is one
                RSPEX=`echo "$RSTMP" | sed -n 's/^<p id=\"nextpage\">[^<]*<a href=\"\([^"]*\)">.*/\1/p'`

                # Did we find a link?
                if [ -z "${RSPEX}" ] ; then

                        # No, we won't process any more pages, and we display the last page with the copyright notice
                        RSNPG="FALSE"
                        RSSTY="$RSTMP"

                else

                        # Yes - we omit the copyright except on the last page
                        RSSTY=`echo "$RSTMP" | egrep -v '<p>.. Copyright'`

                fi

                # Check if we are displaying the first page
                if [ "${RSPGN}" = "1" ] ; then

                        # We print the headline:
                        echo "$RSHDL"

                        # We also print the subtext that usually appears beneath it (usually a Register staff witticism)
                        echo "$RSSTY" | sed -n 's/[^<]*<p class="standfirst">\([^<]*\).*/\1/p' | head -n 1 | fold -s -w $COLUMNS

                        echo

                        # We also print the author
                        echo "$RSSTY" | sed -n 's/[^<]*<p class="byline">\([^<]*\)<[^>]*>\([^<]*\).*/\1\2/p' | fold -s -w $COLUMNS

                        echo

                fi

                # Now we print the article itself, while stripping out any tags, non-ASCII characters, etc.
                echo "$RSSTY" | \

                        # We're only interested in body text (this appears between <p> and </p> tags)
                        egrep '^<p>.*</p>' | \

                        # Substitute <p> tags for carriage returns
                        sed -e 's/<\/p>/\n/g' | \

                        # Substitute ampersand, angle bracket, quotation, pound, copyright and registered trademark directives, for the real thing
                        sed -e 's/amp;/\&/g' -e 's/lt;/</g' -e 's/gt;/>/g' -e 's/quot;/\"/g' -e 's/pound;/GBP/g' -e 's/copy;/\(C\)/g' -e 's/reg;/\(R\)/g' | \

                        # Replace crossed out "we didn't mean to say that" editorial text with the UNIX shell equivalent :)
                        sed -e 's/<del>\([^<]*\)<\/del>/\1^H^H^H^H^H/g' | \

                        # Remove any remaining tags
                        sed -e 's/<[^>]*>//g' | \

                        # Fix the hyphen between copyright dates
                        sed -e 's/...Copyright \(....\)...\(....\)/Copyright \1-\2/' | \

                        # Remove non-printable ASCII characters
                        tr -c '\11\12\40-\176' ' ' | \

                        # Fill any long spaces between words with dashes (sometimes these are used, and are outside the range of ASCII)
                        sed -e 's/\([^ ]\)   \([^ ]\)/\1 - \2/g' -e '$d' | \

                        # Finally, justify the text so it's more readable on the console
                        fold -s -w $COLUMNS

                # Increment page number
                RSPGN=`expr ${RSPGN} + 1`
        done
else

        # If we are called with an out-of-range (or non-existent) headline number, we'll be nice and show the list:
        echo "Available headlines:"
        echo
        echo "$RSIDX"
        echo
        echo "Use $0 [headline number] to view one of the above articles."
        echo

fi
