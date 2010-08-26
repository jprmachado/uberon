
:- use_module(bio(bioprolog_util)).
:- use_module(bio(ontol_db)).
:- use_module(bio(metadata_db)).
:- use_module(bio(metadata_nlp)).
:- use_module(bio(ontol_reasoner)).
:- use_module(bio(index_util)).
:- use_module(bio(tabling)).
:- use_module(bio(mode)).
:- use_module(bio(dbmeta)).
:- use_module(bio(graph)).
:- use_module(bio(simmatrix)).
:- use_module(bio(metadata_mappings)).
:- use_module(library(porter_stem),[]).

idspace_taxon('FMA','NCBITaxon:9606').
idspace_taxon('FBbt','NCBITaxon:7227').
idspace_taxon('WBbt','NCBITaxon:6239').
idspace_taxon('MA','NCBITaxon:10088').
idspace_taxon('EMAP','NCBITaxon:10088').
idspace_taxon('EMAPA','NCBITaxon:10088').
idspace_taxon('EHDAA','NCBITaxon:9606').
idspace_taxon('ZFA','NCBITaxon:7955').
idspace_taxon('TAO','NCBITaxon:32443').
idspace_taxon('XAO','NCBITaxon:8353').
idspace_taxon('AAO','NCBITaxon:8292').
idspace_taxon('HAO','NCBITaxon:7399').
idspace_taxon('SPD','NCBITaxon:6893').
idspace_taxon('TADS','NCBITaxon:6939').
idspace_taxon('TGMA','NCBITaxon:44484').

class_covers_taxon_summary(T,NumCs) :-
        aggregate(count,C,class_covers_taxon(C,T),NumCs).

lca(T1,T2,T) :-
        subclass(T1,T),
        subclass(T2,T),
        \+ ((
             subclass(T1,T3),
             subclass(T2,T3),
             T3\=T,
             subclass(T3,T))).

index_lca_taxon :-
        materialize_index(lca_taxon_u(1)).

lca_taxon(T) :-
        idspace_taxon(_,T1),
        idspace_taxon(_,T2),
        lca(T1,T2,T).

lca_taxon_u(T) :-
        setof(T,lca_taxon(T),Ts),
        member(T,Ts).


class_covers_taxon(C,T) :-
        class(C),
        lca_taxon_u(T),
        \+ \+ test_class_covers_taxon(C,T).

class_covers_taxon_min(C,T) :-
        class(C),
        id_idspace(C,'UBERON'),
        setof(T1,test_class_covers_taxon_direct(C,T1),T1s),
        lca_taxon_u(T),
        forall(member(T1,T1s),
               subclass(T1,T)),
        \+ ((lca_taxon_u(Tx),
             subclass(Tx,T),
             Tx\=T,
             forall(member(T1,T1s),
                    subclass(T1,Tx)))).

class_not_covers_taxon(C,T) :-
        class(C),
        lca_taxon_u(T),
        \+ test_class_covers_taxon(C,T).

test_class_covers_taxon(C,T) :-
        parent(C1,C),
        entity_xref(C1,X),
        id_idspace(X,S),
        idspace_taxon(S,T1),
        subclass(T1,T),
        lca_taxon(T).

test_class_covers_taxon_direct(C,T) :-
        parent(C1,C),
        entity_xref(C1,X),
        id_idspace(X,S),
        idspace_taxon(S,T).

%% class_taxon_invalid(UberonViolatingClass,ExtClass,Taxon,UberonClassWithTaxonRestriction,OnlyInThisTaxon)
class_taxon_invalid(U,X,T,Y,TY) :-
	class(U),
	entity_xref(U,X),
	id_idspace(X,S),
	idspace_taxon(S,T),
	bf_parentRT(U,Y),
	restriction(Y,only_in_taxon,TY),
	debug(tax,'~w ~w check: ~w',[X,T,TY]),
	\+ subclassRT(T,TY).

class_taxon_invalid(U,X,T,Y,TY) :-
	class(U),
	entity_xref(U,X),
	id_idspace(X,S),
	idspace_taxon(S,T),
	bf_parentRT(U,Y),
	restriction(Y,never_in_taxon,TY),
	debug(tax,'~w ~w check: ~w',[X,T,TY]),
	subclassRT(T,TY).


t:-
        forall(restriction(C,broader,P),
               (   inf(C,P,Goal),
                   write('ontol_db:'),
                   writeq(Goal),
                   write('.'),nl)).

inf(C,P,Goal):-
        Goal=subclass_i(C,P),
        Goal,
        !.
inf(C,P,Goal):-
        Goal=restriction_i(C,part_of,P),
        Goal,
        !.
inf(C,P,Goal):-
        Goal=other(C,P),
        Goal,
        !.
inf(C,P,no(C,P)).


% convert MIAA broader relations to is_a; only if there is a subclass chain in ont
ontol_db:subclass(C,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        subclassT(CX,PX),
        xref(P,PX).

% convert MIAA broader relations to is_a; only if there is a relation chain in ont
ontol_db:restriction(C,part_of,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        parent_overT(part_of,CX,PX),
        xref(P,PX).

ontol_db:restriction(C,other,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        parentRT(part_of,CX,PX),
        xref(P,PX).

xref(C,X):-
        entity_alternate_identifier(C,X).


wpxref_url(X,Page,URL) :-
	atom_concat('Wikipedia:',Page,X),
	atom_concat('http://dbpedia.org/resource/',Page,URL).

%% class_page_canonical(?C,?Page,?CanonicalTo)
% Page is e.g. Amnion
% CanonicalURL is the canonical URL
class_page_canonical(C,Page,CanonicalURL):-
	def_xref(C,X),
	wpxref_url(X,Page,URL),
	dbpedia_canonical(URL,CanonicalURL).

class_newdef(C,Def) :-
	def(C,'.'),
	class_page_canonical(C,_,URL),
	rdf(URL,'http://dbpedia.org/property/abstract',literal(lang(en,Def1))),
	atom_concat(Def1,' [WP,unvetted].',Def).

dbpedia_devfrom(Post,Pre) :-
	class_page_canonical(Pre,_,XPre),
	rdf(XPre,'http://dbpedia.org/property/givesriseto',XPost),
	class_page_canonical(Post,_,XPost),
	\+ restriction(Post,develops_from,Pre),
	\+ restriction(Pre,develops_into,Post).

dbpedia_syn(C,Syn) :-
	class_page_canonical(C,_,Canonical),
	rdf(SynURL,'http://dbpedia.org/property/redirect',Canonical),
	atom_concat('http://dbpedia.org/resource/',SynPage,SynURL),
	concat_atom(Toks,'_',SynPage),
	concat_atom(Toks,' ',SynUC),
	downcase_atom(SynUC,Syn),
	term_token_stemmed(Syn,SynStemmed,true),
	\+entity_label_token_stemmed(_,_,SynStemmed,true).

dbpedia(Page) :-
	setof(Page,T^rdf(Page,'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',T),Pages),
	member(Page,Pages).

dbpedia_new(URL) :-
	dbpedia(URL),
	atom_concat('http://dbpedia.org/resource/',_Page,URL),
	\+class_page_canonical(_,_,URL).



	
	

dbpedia_canonical(InURL,CanonicalURL) :-
	rdf(InURL,'http://dbpedia.org/property/redirect',CanonicalURL).
dbpedia_canonical(InURL,InURL) :-
	\+ \+ rdf(InURL,'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',_).

uberon_thumbnail(C,Img) :-
        class_page_canonical(C,_,X),
        rdf(X,'http://dbpedia.org/ontology/thumbnail',Img).

        

idspace_map('TAO',_) :- fail,!.
idspace_map('MIAA',_) :- fail,!.
idspace_map('ZFA','ZFA/ZFS') :- !.
idspace_map('ZFS','ZFA/ZFS') :- !.
idspace_map('BILA','BILA/BILS') :- !.
idspace_map('BILS','BILA/BILS') :- !.
idspace_map('galen','GALEN') :- !.
idspace_map(X,X).

idspace_desc('ZFA/ZFS','Zebrafish').
idspace_desc('BILA/BILS','Bilateria').
idspace_desc('FMA','Adult human').
idspace_desc('MA','Adult mouse').
idspace_desc('EHDAA','Human (developmental)').
idspace_desc('EMAPA','Mouse (abstract)').
idspace_desc('EMAP','Mouse (developmental)').
idspace_desc('BTO','plant and animal').
idspace_desc('GAID','plant and animal').
idspace_desc('NIF_GrossAnatomy','Mammalian brain').
idspace_desc('ncithesaurus','Mouse and human').
idspace_desc('HOG','homologous grouping (vertebrate)').
idspace_desc('OpenCyc','general').
idspace_desc('TAO','Teleost').
idspace_desc('XAO','Xenopus').
idspace_desc('FBbt','Drosophila').
idspace_desc('WBbt','C elegans').
idspace_desc('MIAA','general').
idspace_desc('MAT','general').
idspace_desc('EFO','General (experimental factors)').
idspace_desc('GALEN','Medical, human').



uberon_xref_in(E,X,S) :-
	entity_xref(E,X),
	id_idspace(X,S1),
	idspace_map(S1,S).

uberon_xref_count(S,SD,Num) :-
	aggregate(count,
		  X,
		  E^uberon_xref_in(E,X,S),
		  Num),
	Num > 32,
	idspace_desc(S,SD).

class_count_by_ont(Ont,Num) :-
	aggregate(count,X,(class(X),id_idspace(X,Ont)),Num).


uberon_compare_sets_by_relT(X1,X2,Rel,Diff) :-
	findall(C,parent_overT(Rel,C,X1),Set1),
	findall(C,parent_overT(Rel,C,X2),Set2),
	debug(uberon,'comparing: ~w -VS- ~w',[Set1,Set2]),
	uberon_compare_sets(Set1,Set2,Diff).
uberon_compare_sets_by_rel(X1,X2,Rel,Diff) :-
	findall(C,parent(C,Rel,X1),Set1),
	findall(C,parent(C,Rel,X2),Set2),
	debug(uberon,'comparing: ~w -VS- ~w',[Set1,Set2]),
	uberon_compare_sets(Set1,Set2,Diff).
uberon_compare_sets_by_query(T1,Q1,T2,Q2,Diff) :-
	findall(T1,Q1,Set1),
	findall(T2,Q2,Set2),
	uberon_compare_sets(Set1,Set2,Diff).

uberon_compare_sets(Set1,Set2,Diff) :-
	member(X1,Set1),
	entity_xref(U,X1),
	uberon_in_set(U,Set2,Diff).
uberon_compare_sets(Set1,Set2,Diff) :-
	member(X2,Set2),
	entity_xref(U,X2),
	uberon_in_set(U,Set1,Diff).

uberon_in_set(U,Set2,match-U) :-
	entity_xref(U,X2),
	member(X2,Set2),
	!.
uberon_in_set(U,Set2,diff-U) :-
	entity_xref(U,X2),
	member(Random,Set2),
	id_idspace(Random,S),
	id_idspace(X2,S),
	!.
uberon_in_set(U,_,no_xref-U).

uberon_sibpair(U,A,B) :-
	entity_xref(U,A),
	class(A),
	entity_xref(U,B),
	class(B),
	A\=B,
	id_idspace(A,AO),
	id_idspace(B,BO),
	AO\=BO.

uberon_sibpair_all_textmatches(U,A,B,L) :-
	uberon_sibpair(U,A,B),
	findall(Tok,uberon_sibpair_textmatches(U,A,B,Tok),L).

uberon_sibpair_textmatches(U,A,B,Tok) :-
	uberon_sibpair(U,A,B), % no need to index...
	entity_label_token_stemmed(A,_AN,Tok,true),
	entity_label_token_stemmed(B,_BN,Tok,true).

	
		
% for paper:
aolist(['UBERON','FMA','MA','EMAP','ZFA','XAO','FBbt','WBbt','BTO']).


% MUST MATCH
aostat('Classes').
aostat('Relationships').
aostat('Relations').
aostat('% Defined (text)').
aostat('% Defined (computable)').

aostat1('Classes',Num,Ont) :- aggregate(count,X,(class(X),id_idspace(X,Ont)),Num).
aostat1('Relationships',Num,Ont) :- aggregate(count,X-Y,(parent(X,Y),id_idspace(X,Ont)),Num).
aostat1('Relations',Num,Ont) :- aggregate(count,R,X^Y^(parent(X,R,Y),id_idspace(X,Ont)),Num).
aostat1('% Defined (text)',Pct,Ont) :-
	aggregate(count,D,X^(def(X,D),id_idspace(X,Ont)),Num),
	pct_classes(Ont,Num,Pct).
aostat1('% Defined (computable)',Pct,Ont) :- 
	aggregate(count,X,G^(genus(X,G),id_idspace(X,Ont)),Num),
	pct_classes(Ont,Num,Pct).


pct_classes(Ont,Num,Pct) :-
	aostat('Classes',Tot,Ont),
	Pct is floor((Num/Tot)*100 + 0.5).

aostat(S,V,O) :- aostat1(S,V,O),!.
aostat(_,'-',_).

aostatrow(['' | L]) :-
	aolist(L).		% header
aostatrow(['' | L2]) :-
	aolist(L),
	maplist(idspace_taxon,L,L2).
aostatrow([S|L]) :-
	aolist(Onts),
	aostat(S),
	findall(V,(member(Ont,Onts),
		   aostat(S,V,Ont)),L).

aostatrow_term(X) :-
	aostatrow(L),
	X=..L.
	

cdef_refs_u(cdef(_,L)) :-
	member(_=X,L),
	id_idspace(X,'UBERON'),
	!.
goxp_newlink(A,B) :-
	class_cdef(A,AD),
	cdef_refs_u(AD),
	id_idspace(A,'GO'),
	class_cdef(B,BD),
	cdef_refs_u(BD),
	id_idspace(B,'GO'),
	\+ \+ subclassX(AD,BD),
	\+ subclassRT(A,B).

sandwich(B,FB) :-
        entity_xref(UA,A),
        id_idspace(UA,'UBERON'),
        parent(A,B),
        id_idspace(A,'MA'),
        \+entity_xref(_,B),
        entity_xref(UA,FA),
        id_idspace(FA,'FMA'),
        parent(FA,FB),
        entity_xref(_UB,FB),
        parent(B,C),
        %debug(sandwich,'A=~w - B=~w // ~w,~w',[A,B,FA,FB]),
        entity_xref(UC,C),
        parent(FB,FC),
        entity_xref(UC,FC).

organ_association_s(X,Y) :-
        organ_association(X,_,Y,_,_,_).
organ_association_s(X,Y) :-
        organ_association(Y,_,X,_,_,_).

hog_xref(U,X,Y) :-
        organ_association_s(X,Y),
        entity_xref(U,X),
        \+entity_xref(U,Y),
        \+entity_xref(_,Y).

% ----

path_dist(ID,PID,Dist) :-
	class(ID),
	debug(path_dist,'path_dist(~w)',[ID]),
	ids_ancestor_dists([0-ID],[],[],L),
	member(Dist-PID,L).

ids_ancestor_dists([Dist-ID|DIDs],DoneIDs,DistAncPairs,DistAncPairsFinal) :-
        Dist2 is Dist+1,
        % ord_memberchk/1?
	setof(Dist2-XID,(parent(ID,XID),\+member(XID,DoneIDs)),Parents),
	!,
	ord_union(DistAncPairs,Parents,DistAncPairsNew),
        ord_union(DIDs,Parents,NewDIDs),
	ids_ancestor_dists(NewDIDs,[ID|DoneIDs],DistAncPairsNew,DistAncPairsFinal).
ids_ancestor_dists([Dist-ID|DIDs],DoneIDs,DistAncPairs,DistAncPairsFinal) :-
	!,
	ids_ancestor_dists(DIDs,[Dist-ID|DoneIDs],DistAncPairs,DistAncPairsFinal).
ids_ancestor_dists([],_,DistAncPairs,DistAncPairs).

% ----------------------------------------
% semantic similarity of mapping
% ----------------------------------------

% simJ using uberon.
% only include classes that...

:- dynamic user:simindex_prepared/0.

simindex_prepare :-
        user:simindex_prepared,
        !.

simindex_prepare :-
        !,
        assert(user:simindex_prepared),
        debug(sim,'preparing UBERON index',[]),
        table_pred(ontol_db:bf_parentRT/2),
        table_pred(path_dist/2),
        %generate_term_indexes(C,P,(member(C,Cs),bf_parentRT(C,P),id_idspace(P,'UBERON'))),
        generate_term_indexes(C,P,class_uberon_anc(C,P)),
        debug(sim,'DONE preparing UBERON index',[]).

class_uberon_anc_dist(C,Dist) :-
        class_uberon_anc_dist(C,_,Dist).

class_uberon_anc_dist(C,P,Dist) :-
        path_dist(C,P,Dist),
        id_idspace(P,'UBERON').

class_uberon_anc(C,P) :-
        class(C),
        \+ id_idspace(C,'UBERON'),
        entity_label(C,_),
        aggregate(min(Dist),class_uberon_anc_dist(C,Dist),MinDist),
        class_uberon_anc_dist(C,P1,MinDist),
        bf_parentRT(P1,P),
        id_idspace(P,'UBERON').


/*
simindex_prepare :-
        !,
        assert(user:simindex_prepared),
        debug(sim,'preparing UBERON index',[]),
        table_pred(ontol_db:bf_parentRT/2),
        table_pred(path_dist/3).
        %materialize_index(path_dist(1,1,0)).
  */

/*
class_pair_lcp_dist(A,B,Dist) :-
        class_pair_lcp_dist(A,B,_,Dist).
class_pair_lcp_dist(A,B,C,Dist) :-
        path_dist(A,C,DA),
        path_dist(B,C,DB),
        Dist is (DA+DB)-2.
*/

uberon_class_pair_simj(A,B,S) :-
        simindex_prepare,
        feature_pair_simj(A,B,S).

/*
uberon_class_pair_simj(A,B,C,S) :-
        simindex_prepare,
        aggregate(min(Dist),class_pair_lcp_dist(A,B,Dist),S),
        class_pair_lcp_dist(A,B,C,S),
        debug(sim,'  dist(~w,~w) = ~w :: ~w',[A,B,C,S]).
*/
        
/*
uberon_class_pair_simj(A,B,S) :-
        simindex_prepare,
        setof(AP,bf_parentRT(A,AP),APs),
        setof(BP,bf_parentRT(B,BP),BPs),
        ord_intersection(APs,BPs,CPs),
        debug(sim,'  lca(~w,~w) = ~w',[A,B,CPs]),
        %debug(sim,'  lca(~w,~w) = ~w ::: ~w // ~w',[A,B,CPs,APs,BPs]),
        aggregate(min(Dist),class_pair_lcp_dist(A,B,APs,BPs,CPs,Dist),S),
        debug(sim,'  dist(~w,~w) = ~w',[A,B,S]).
*/
        

mapping_semsim(M,S,T,Sim) :-
	rdf_has(M,'http://protege.stanford.edu/mappings#source',Sx),
	bpuri_id(Sx,S),
	rdf_has(M,'http://protege.stanford.edu/mappings#target',Tx),
	bpuri_id(Tx,T),
        (   uberon_class_pair_simj(S,T,Sim)
        ->  true
        ;   Sim=0).


bpuri_id(X,ID) :-
	concat_atom(L,'/',X),
	reverse(L,[IDx|_]),
	mapid(IDx,ID).
mapid(ID,ID) :- concat_atom([_,_],':',ID),!.
mapid(N,ID) :- concat_atom(Toks,'_',N),concat_atom(Toks,' ',N2),entity_label(ID,N2),!.
