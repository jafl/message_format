[![Build Status](https://secure.travis-ci.org/jafl/message_format.png?branch=master)](http://travis-ci.org/jafl/message_format)

Introduction
------------

This package provides an extension to java.text.MessageFormat with the
following features:

   * Named placeholders.  Pass in a Map<String, Object> instead of Object[].
   * OGNL expressions in the parameter names, e.g., name.first would look up
     "name" in the Map and extract the member "first".
   * Additional format types:
      * string:     Force conversion of the Object to a String.
      * html:       If the Object is a String, convert special characters to
                    HTML equivalents, e.g., < --> &lt;
      * htmlstring: both of the above
      * If you want to apply these format types to all parameters implicitly,
        use the Options object.
   * More complex parameter transformation by implementing ArgTransformer.
   * Default FormatStyle for each FormatType, e.g., you can set the default
     style for "date" to "medium".  The default is per locale, so you can
     set the default for "number" to "#,##0.00" in en_US and "#.##0,00" in
     de_DE.
      * You can register a hook to return the default FormatStyle for each
        FormatType, instead of explicitly calling setDefaultFormatStyle().
        One use for this is to load configuration from resource bundles
        on an as-needed basis.
   * If you like setting defaults, but have strings with numeric placeholders,
     call setBuildParameterMap(false).  Numeric placeholders will be left
     alone, except for inserting default FormatStyles.

The package includes convenience functions to emulate the
MessageFormat.format() API, but just as with MessageFormat, you should
cache the final MessageFormat objects since they are very expensive to
construct.

Installation
------------

This package is built using Maven (http://maven.apache.org/).  Once you have
installed Maven, simply run "mvn clean install", and it will build the jar.

Dependencies
------------

This package requires the following 3rd party libraries:

   * Apache Commons BeanUtils (http://commons.apache.org/beanutils/)
   * Apache Commons Lang (http://commons.apache.org/lang/)

Building the package requires the following 3rd party libraries:

   * JFlex (http://jflex.de/) and the associated maven plugin

These dependencies are automatically downloaded by Maven when the package
is built.

Notes
-----

Unfortunately, maven-jflex-plugin does not support %ctorarg, so instead of
passing the Locale to the constructor, you have to call setLocale() after
constructing MessageFormatScanner.  Hopefully, this will be rectified soon.
