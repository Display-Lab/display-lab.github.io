---
layout: post
title:  "KGrid and Message Tailoring System"
date:   2017-08-22 10:40:00 -0500
---
# Landis-Lewis Lab

## Message Tailoring System Components

Message Tailoring is about selecting the appropriate behavior change intervention for the recipient.  
The components of the methodology for selecting interventions is illustrated below.

![message tailoring]({{site.baseurl}}/assets/img/reason_diagram.svg)

- **Templates:** Templates of interventions. 
Annotated with properties such as `peer_comparison`, `normaative`, or `achievable_benchmark`
- **Situation:** The attributes of the situation of the group or individual that is the recipient of the message.  
Annotate with properties such as `low_performance`, `promotion_focus`, or `obligation_behavior`.
- **Candiates:** Combination of Situation x Templates.  
The number of candidates is the same as the number of templates as only one situation at a time is considered.  
A candidate contains all the attributes of its parent template and situation.
- **ISI:** Intervention-Situation-Interaction is derived from a psychological theory.
It makes inferences about candidate interventions based upon their attributes.
The current implementation of an ISI is a set of SWRL rules that assert which candidates are acceptable candidates.


## KGrid Usage

### Service Knowledge Objects
KGrid knowledge objects encapsulate a "I know how to..." with the relevant metadata.
As an example, consider a knowledge object that asserts "I know how to construct a svg formatted graph artifact from plot data."

```R
generate_category_plot <- function(plot_data, plot_title, y_label, cat_labels){
  
  plot <- ggplot(plot_data, aes(x = timepoint, y = count)) +
    geom_col(aes(fill = event)) +
    scale_y_continuous(breaks=pretty_breaks()) +
    labs(title = plot_title, x = " ", y = y_label) +
    scale_fill_viridis(
      discrete = TRUE,
      breaks = levels(plot_data$event),
      labels = cat_labels
    )
  
  return(plot2svg(plot))  
}
```
The above would be the code of the knowledge object.  Attached to that would be FIO and RIDO tripples such as:
- `(. rido:number_of_dimensions "2")`
- `(. fio:has_attribute fio:peer_comparison)`
- `(. fio:has_attribute fio:self_comparison)`

In this way, the knowledge about how to do a thing and the associated metadata used to reason about the context of that knowledge is together in a single container.

### Resource Knowledge Objects
In order to store reuseable and actionable knowledge that is not directly executeable a kobject that retuns it's contents as a resource can be used.
Consider the actionable knoweldge of a particular ISI.
It is a simple rule defining an acceptable candidate.

```
Candidate(?c) ^ hasAttribute(?c, AchievableBenchmark) -> AcceptableCandidate(?c)
```

The above rule would be stored in the knowledge object along with some FIO tripples about it.  Some examples could be:

- `(. fio:literature_reference doi:11.1234/0123456789.ch1)`
- `(. fio:behavior_change_mechanism ffio:self-efficacy)`

This knoweldge object is informative about which candidates are acceptable candidates and includes the metadata that links to the origin of the knowledge and a representation of the associated mechanism that could facilitate further reasoning.

### KGrid Collections
Our collections will be a curated list of knowledge objects and the associated metadata which would be inappropriate to be contained by the list members themselves.  
1. Since intervention templates are not bound to a particular psychological theory,
2. and a template may be appropriate for multiple theories.
3. Maintaining a collection for each theory facilitates selection of templates to use when generating candidate interventions. 
