<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:mml="http://www.w3.org/1998/Math/MathML" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:util="http://cudl.lib.cam.ac.uk/xtf/ns/util"
    xmlns:transkribus="http://cudl.lib.cam.ac.uk/xtf/ns/transkribus-import"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:output method="xml" indent="no" encoding="UTF-8" exclude-result-prefixes="#all"/>
    
    <xsl:include href="lib/util.xsl"/>
    <xsl:include href="lib/pagination-core.xsl"/>
    <xsl:include href="lib/default-text-tidying.xslt"/>
    
    <xsl:param name="full_path_to_cudl_data_source" as="xs:string*"/>
    
    <xsl:variable name="selected_path_to_cudl_source">
        <xsl:choose>
            <xsl:when test="replace($full_path_to_cudl_data_source,'/$','') != ''">
                <xsl:value-of select="replace($full_path_to_cudl_data_source,'/$','')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="xslt_repo_root" select="concat(replace(resolve-uri('.'),'/$',''), '/..')" as="xs:string"/>
                <xsl:value-of select="string-join(($xslt_repo_root, 'staging-cudl-data-source'), '/')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="subpath_to_tei_dir" select="'items/data/tei'"/>
    
    <xsl:variable name="export_root" select="/*"/>
    
    <xsl:variable name="cudl_filename" select="//tei:idno[@type='external'][matches(.,'https://cudl.lib.cam.ac.uk/iiif/')]/tokenize(replace(replace(.,'/simple$',''),'/\s*$',''), '/')[last()]" />
    <xsl:variable name="path_to_cudl_file" select="replace(concat(string-join(($selected_path_to_cudl_source, $subpath_to_tei_dir, $cudl_filename),'/'),'/',$cudl_filename,'.xml'),'^file:','')"/>
    <xsl:variable name="cudl_root" select="if (doc-available($path_to_cudl_file)) then doc($path_to_cudl_file)/* else ()"/>
    
    <xsl:key name="surface_elems" match="//tei:surface" use="replace(@xml:id, '^\D+', '')" />
    <xsl:key name="cudl_pb" match="//tei:pb" use="replace(replace(@facs, '^\D+(\d+)$', '$1'),'^0+', '')" />
    
    <!-- Low priority template to ensure that all nodes are copied - unless
         a template with a higher priority (either specified or automatically
         computed) is supplied.
    -->
    <xsl:template match="node() | @*" mode="#all" priority="-1">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current" />
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="text()" mode="add-page-content">
        <xsl:call-template name="process-text-nodes">
            <xsl:with-param name="string" select="."/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:variable name="paginated_content" as="item()*">
        <xsl:apply-templates select="//tei:body" mode="paginate"/>
    </xsl:variable>
    
    <xsl:template match="tei:body" mode="paginate">
        <xsl:variable name="context" select="."/>
        <xsl:for-each select="descendant::tei:pb[util:has-valid-context(.)]">
            <xsl:variable name="next-page" select="(following::tei:pb[util:has-valid-context(.)])[1]" as="item()*"/>
            <xsl:variable name="final-node" select="if ($next-page) then $next-page else following::node()[last()]"/>
            <xsl:variable name="image-number" select="replace(@facs,'#', '')"/>
            
            <div xml:id="surface-{$image-number}" facs="#{$image-number}" type="transkribus_page_container">
                <xsl:apply-templates select="util:page-content(.,$final-node, $context)" mode="pagination-postprocess"/>
            </div>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="tei:body" priority="2" mode="pagination-postprocess">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:body[not(child::text()[normalize-space(.)])]
                                 [not(*[not(self::tei:div)])]
                                 [count(tei:div) eq 1]
                                 /tei:div" mode="pagination-postprocess">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="/" mode="#default">
        <xsl:variable name="surface_elems_exist" select="exists(/tei:TEI/tei:facsimile/tei:surface)" as="xs:boolean"/>
        <xsl:variable name="body_pbs_exist" select="exists(.//tei:body//tei:pb)" as="xs:boolean"/>
        
        <xsl:choose>
            <xsl:when test="$body_pbs_exist and $surface_elems_exist">
                <xsl:apply-templates select="$cudl_root"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="error_messages" as="xs:string*">
                    <xsl:if test="not($body_pbs_exist)">
                        <xsl:sequence select="'ERROR: No pb elements in body'"/>
                    </xsl:if>
                    <xsl:if test="not($surface_elems_exist)">
                        <xsl:sequence select="'ERROR: No surface elements in facsimile'"/>
                    </xsl:if>
                </xsl:variable>
                <xsl:for-each select="$error_messages">
                    <xsl:comment select="."/>
                    <xsl:message select="."/>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="/tei:TEI">
        <xsl:text>&#10;</xsl:text>
        <xsl:for-each select="root(.)/processing-instruction()">
            <xsl:copy-of select="."/>
            <xsl:text>&#10;</xsl:text>
        </xsl:for-each>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:revisionDesc/tei:change[. is (parent::*/tei:change)[last()]]">
        <xsl:copy-of select="."/>
        <xsl:value-of select="util:indent-elem(.)"/>
        <xsl:call-template name="write-change"/>
    </xsl:template>
    
    <xsl:template match="tei:teiHeader[not(tei:revisionDesc)]/*[. is (parent::*/*)[last()]]" priority="22">
        <xsl:copy-of select="."/>
        <xsl:value-of select="util:indent-elem(.)"/>
        <revisionDesc>
            <xsl:value-of select="util:indent-to-depth(count(ancestor::*) +1)"/>
            <xsl:call-template name="write-change"/>
            <xsl:value-of select="util:indent-elem(.)"/>
        </revisionDesc>
    </xsl:template>
    
    <xsl:template match="tei:revisionDesc[not(tei:change)]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="util:indent-to-depth(count(ancestor::*) +1)"/>
            <xsl:call-template name="write-change"/>
            <xsl:value-of select="util:indent-elem(.)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:surface">
        <xsl:variable name="cudl_context" select="." />
        <xsl:variable name="surface_number" select="replace(@xml:id,'^\D+(\d+)$', '$1')"/>
        <xsl:variable name="imported_surface" select="key('surface_elems', $surface_number, $export_root)"/>
        
        <xsl:copy>
            <xsl:copy-of select="@* except (@lrx, @lry, @ulx, @uly)"/>
            <xsl:copy-of select="$imported_surface/(@lrx, @lry, @ulx, @uly)"/>
            
            <xsl:for-each select="*|comment()">
                <xsl:value-of select="util:indent-elem(.)"/>
                <xsl:apply-templates select="."/>
            </xsl:for-each>
            <xsl:if test="$imported_surface[tei:zone]">
                <xsl:apply-templates select="$imported_surface/tei:zone" mode="add-zone"/>
            </xsl:if>
            <xsl:value-of select="util:indent-elem(.)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:zone" mode="add-zone">
        <xsl:value-of select="util:indent-to-depth(count(ancestor::*) + 2)"/>
        <xsl:copy>
            <xsl:copy-of select="@* except @points"/>
            <xsl:attribute name="points" select="transkribus:rescale(., ancestor::tei:surface[1])"/>
            <xsl:apply-templates select="*|comment()" mode="add-zone"/>
            <xsl:if test="parent::tei:surface">
                <xsl:value-of select="util:indent-to-depth(count(ancestor::*) + 2)"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:zone">
        <!-- Ignore zone elements in CUDL file -->
        <xsl:apply-templates select="*|comment()"/>
    </xsl:template>
    
    <xsl:template match="tei:body">
        <xsl:variable name="pb_elems" select="descendant::tei:pb" as="item()*"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="util:indent-to-depth(count(ancestor::*) + 1)"/>
            <div>
                <xsl:for-each select="$pb_elems">
                    <xsl:variable name="current_pb" select="."/>
                    <xsl:variable name="surface_num" select="replace(@facs, '^\D+(\d+)$', '$1')" as="xs:string"/>
                    <xsl:value-of select="util:indent-elem($current_pb)"/>
                    <xsl:choose>
                        <!-- Expensive replace -->
                        <xsl:when test="$paginated_content[replace(@xml:id, '^\D+(\d+)$', '$1') = $surface_num]">
                            <xsl:apply-templates select="$paginated_content[replace(@xml:id, '^\D+(\d+)$', '$1') = $surface_num]" mode="add-page-content"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates select="$current_pb"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:value-of select="util:indent-to-depth(count(ancestor::*) + 1)"/>
            </div>
            <xsl:if test="$paginated_content[not(replace(@xml:id, '^\D+(\d+)$', '$1') = $pb_elems/replace(@facs, '^\D+(\d+)$', '$1'))]">
                <xsl:variable name="error_message" select="concat('ERROR: Pages (' ,$paginated_content[not(replace(@xml:id, '^\D+(\d+)$', '$1') = $pb_elems/replace(@facs, '^\D+(\d+)$', '$1'))]/@xml:id,') does not matche any pages in the CUDL file')"/>
                <xsl:comment select="$error_message"/>
                <xsl:message select="$error_message"/>
            </xsl:if>
            <xsl:value-of select="util:indent-elem(.)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:div[@type='transkribus_page_container']" mode="add-page-content">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:pb" mode="add-page-content">
        
        <xsl:copy-of select="transkribus:get-cudl-pb(.)"/>
    </xsl:template>
    
    <xsl:template match="tei:ab[not(normalize-space(@type))]/@type" mode="add-page-content"/>
    
    <xsl:template name="write-change">
        <change when="{format-dateTime(current-dateTime(), '[Y4]-[M02]-[D02]T[H02]:[m02]:[s02]')}">
            <xsl:text>Imported Transkribus transcription into main file</xsl:text>
        </change>
    </xsl:template>
    
    <!-- Optimised getters -->
    
    <xsl:function name="transkribus:get-cudl-pb" as="item()*">
        <xsl:param name="imported_pb"/>
        
        <xsl:variable name="target_surface_num" select="$imported_pb/replace(replace(@facs,'^\D+(\d+)$', '$1'),'^0+','')"/>
        <xsl:copy-of select="key('cudl_pb', $target_surface_num, $cudl_root)"/>
    </xsl:function>
    
    <xsl:function name="transkribus:rescale">
        <xsl:param name="zone_elem"/>
        <xsl:param name="imported_surface"/>
        
        <xsl:variable name="cudl_surface" select="key('surface_elems',$zone_elem/ancestor::tei:surface/replace(@xml:id,'^\D+(\d+)$', '$1'), $cudl_root)"/>
        
        <xsl:variable name="cudl_image_width" select="$cudl_surface/(tei:graphic[@width])[1]/replace(@width,'px$','')"/>
        <xsl:variable name="cudl_image_height" select="$cudl_surface/(tei:graphic[@height])[1]/replace(@height,'px$','')"/>
        <xsl:variable name="imported_image_width" select="$imported_surface/replace(@lrx,'px','')"/>
        <xsl:variable name="imported_image_height"  select="$imported_surface/replace(@lry,'px','')"/>
        
        <xsl:if test="every $x in ($cudl_image_width, $cudl_image_height, $imported_image_width, $imported_image_height, tokenize($zone_elem/normalize-space(@points), '[\s+,]')) satisfies $x castable as xs:integer and $zone_elem/normalize-space(@points)[normalize-space(.)]">
            <xsl:variable name="new_coords" as="xs:string*">
                <xsl:for-each select="tokenize($zone_elem/normalize-space(@points), '\s+')">
                    <xsl:variable name="x" select="xs:integer(tokenize(.,',')[1])"/>
                    <xsl:variable name="y" select="xs:integer(tokenize(.,',')[2])"/>
                    
                    <xsl:variable name="new_x" select="transkribus:_rescale_point($x, xs:integer($imported_image_width), xs:integer($cudl_image_width))"/>
                    <xsl:variable name="new_y" select="transkribus:_rescale_point($y, xs:integer($imported_image_height), xs:integer($cudl_image_height))"/>
                    <xsl:sequence select="concat($new_x,',',$new_y)"/>
                </xsl:for-each>
            </xsl:variable>
            
            <xsl:value-of select="string-join($new_coords, ' ')"/>
            
        </xsl:if>
    </xsl:function>
    
    <xsl:function name="transkribus:_rescale_point" as="xs:integer">
        <xsl:param name="point" as="xs:integer"/>
        <xsl:param name="current_max" as="xs:integer"/>
        <xsl:param name="target_max" as="xs:integer"/>
        
        <xsl:value-of select="round(($point div $current_max) * $target_max)"/>
    </xsl:function>

</xsl:stylesheet>