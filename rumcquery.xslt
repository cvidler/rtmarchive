<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text" indent="no"/>
  <xsl:template match="/backup">
    <!-- loop through each device node (of type=0) in the XML -->
    <xsl:for-each select="/backup/devices[type=0]"><!-- generate/process data set --><xsl:value-of select="name"/>,<xsl:value-of select="parameters/entries[@key='IS_HTTPS']/@value"/>,<xsl:value-of select="parameters/entries[@key='PORT']/@value"/>,<xsl:value-of select="parameters/entries[@key='PASSWORD']/@value"/>,<xsl:value-of select="parameters/entries[@key='IP']/@value"/>,<xsl:value-of select="version"/>,<xsl:value-of select="parameters/entries[@key='USER']/@value"/><xsl:text>
</xsl:text></xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
